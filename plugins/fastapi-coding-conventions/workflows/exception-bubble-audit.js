export const meta = {
  name: 'exception-bubble-audit',
  description: 'Check that every domain exception in a FastAPI app reaches the global error handler with the intended status code',
  whenToUse: 'After adding domain exceptions, services, or routes, or before a release, to find exceptions that would surface as 500 errors and routes that catch them',
  phases: [
    { title: 'Discover', detail: 'find exception, service, route, and handler modules' },
    { title: 'Read', detail: 'catalog exceptions and handlers, raise sites, and route handling in parallel' },
    { title: 'Report', detail: 'compare the results and write the report' },
  ],
}

// Optional input: {exceptions, services, routes, handlers}, each a list of paths or
// globs relative to the project root. Keys that are left out are discovered.
const overrides = args && typeof args === 'object' && !Array.isArray(args) ? args : {}

const LIST = { type: 'array', items: { type: 'string' } }

const FILES_SCHEMA = {
  type: 'object',
  required: ['exceptions', 'services', 'routes', 'handlers'],
  properties: { exceptions: LIST, services: LIST, routes: LIST, handlers: LIST },
}

const CATALOG_SCHEMA = {
  type: 'object',
  required: ['exceptions', 'global_handler', 'handlers'],
  properties: {
    exceptions: {
      type: 'array',
      items: {
        type: 'object',
        required: ['name', 'file', 'base', 'status_code', 'is_domain_error'],
        properties: {
          name: { type: 'string' },
          file: { type: 'string' },
          base: { type: 'string' },
          status_code: { type: ['integer', 'null'] },
          is_domain_error: { type: 'boolean' },
        },
      },
    },
    global_handler: {
      type: 'object',
      required: ['exists', 'reads_status_code', 'file'],
      properties: {
        exists: { type: 'boolean' },
        reads_status_code: { type: 'boolean' },
        file: { type: 'string' },
      },
    },
    handlers: {
      type: 'array',
      items: {
        type: 'object',
        required: ['exception', 'status_code', 'file'],
        properties: {
          exception: { type: 'string' },
          status_code: { type: ['integer', 'null'] },
          file: { type: 'string' },
        },
      },
    },
  },
}

const RAISES_SCHEMA = {
  type: 'object',
  required: ['raises'],
  properties: {
    raises: {
      type: 'array',
      items: {
        type: 'object',
        required: ['exception', 'file', 'line', 'method', 'condition'],
        properties: {
          exception: { type: 'string' },
          file: { type: 'string' },
          line: { type: 'integer' },
          method: { type: 'string' },
          condition: { type: 'string' },
        },
      },
    },
  },
}

const ROUTES_SCHEMA = {
  type: 'object',
  required: ['endpoints'],
  properties: {
    endpoints: {
      type: 'array',
      items: {
        type: 'object',
        required: ['method', 'path', 'file', 'line', 'verdict', 'caught'],
        properties: {
          method: { type: 'string' },
          path: { type: 'string' },
          file: { type: 'string' },
          line: { type: 'integer' },
          verdict: { type: 'string', enum: ['LETS_BUBBLE', 'SWALLOWS', 'CONVERTS_TO_HTTPEXCEPTION'] },
          caught: LIST,
        },
      },
    },
  },
}

phase('Discover')
const overrideNote = Object.keys(overrides).length
  ? `\nThe user supplied these paths or globs. Expand them and use them for those keys instead of searching: ${JSON.stringify(overrides)}`
  : ''
const files = await agent(
  `Find the files for an exception bubble-up audit of this FastAPI project. Look at the source tree first.
Return paths relative to the project root:
- exceptions: modules that define domain exception classes (often under src/domain/exceptions/)
- services: service modules that raise those exceptions (often under src/services/)
- routes: API route modules (often under src/api/routes/)
- handlers: files that register exception handlers (often src/api/exception_handlers.py and src/main.py)
Leave out tests, migrations, and virtual environments.${overrideNote}`,
  { label: 'discover', phase: 'Discover', schema: FILES_SCHEMA, effort: 'low' },
)

if (!files || files.exceptions.length === 0) {
  return { report: 'No domain exception modules were found, so there is nothing to audit. Pass {exceptions: [...]} to point the audit at them.' }
}
log(`Found ${files.exceptions.length} exception, ${files.services.length} service, ${files.routes.length} route, and ${files.handlers.length} handler files`)

phase('Read')
const exceptionFiles = files.exceptions.join(', ')
const [catalog, raises, routes] = await parallel([
  () => agent(
    `Read these exception modules: ${exceptionFiles}
and these handler files: ${files.handlers.join(', ')}.
For every exception class, give its name, file, direct base class, its own status_code attribute (null when it only inherits one), and is_domain_error: true when it inherits, directly or indirectly, from the project's domain error base class.
global_handler: exists is true when a handler is registered for that base class; reads_status_code is true when the handler builds the response from exc.status_code; file is where it is registered.
handlers: every registered exception handler, with its exception class and the status code it returns (null when it reads exc.status_code).`,
    { label: 'catalog', phase: 'Read', schema: CATALOG_SCHEMA, effort: 'medium' },
  ),
  () => agent(
    `Read these service modules: ${files.services.join(', ')}.
List every place that raises an exception class defined in these modules: ${exceptionFiles}.
For each: the exception name, file, line, the method that raises it, and the condition in one sentence. Ignore built-in exceptions.`,
    { label: 'raise sites', phase: 'Read', schema: RAISES_SCHEMA, effort: 'medium' },
  ),
  () => agent(
    `Read these route modules: ${files.routes.join(', ')}.
For every endpoint, give the HTTP method, path, file, line, the exception names its handler catches, and a verdict:
- LETS_BUBBLE: it does not catch any exception class defined in ${exceptionFiles}
- SWALLOWS: it catches one and returns normally
- CONVERTS_TO_HTTPEXCEPTION: it catches one and raises HTTPException instead`,
    { label: 'route handling', phase: 'Read', schema: ROUTES_SCHEMA, effort: 'medium' },
  ),
])

if (!catalog || !raises || !routes) {
  return { report: 'A reading agent failed, so the comparison would be incomplete. Rerun the workflow.' }
}

// Compare in plain code: no agent needed.
const defined = new Map(catalog.exceptions.map((e) => [e.name, e]))
const baseClasses = new Set(catalog.exceptions.map((e) => e.base))
const registered = new Set(catalog.handlers.map((h) => h.exception))
const raisedNames = new Set(raises.raises.map((r) => r.exception))
const globalHandles = catalog.global_handler.exists && catalog.global_handler.reads_status_code

const gaps = {
  // Raised, but neither a domain error covered by the global handler nor registered: becomes a 500.
  unhandled: raises.raises.filter((r) => {
    const e = defined.get(r.exception)
    return !registered.has(r.exception) && !(e && e.is_domain_error && globalHandles)
  }),
  routeViolations: routes.endpoints.filter((e) => e.verdict !== 'LETS_BUBBLE'),
  neverRaised: catalog.exceptions.filter((e) => !raisedNames.has(e.name) && !baseClasses.has(e.name)).map((e) => e.name),
  staleHandlers: catalog.handlers.filter((h) => !raisedNames.has(h.exception) && !baseClasses.has(h.exception)),
  missingGlobalHandler: !globalHandles,
}
log(`${gaps.unhandled.length} unhandled raise sites, ${gaps.routeViolations.length} route violations, ${gaps.neverRaised.length} unused exceptions`)

phase('Report')
const report = await agent(
  `Write a short markdown report for an exception bubble-up audit of a FastAPI app.
The rules being checked: services raise domain exceptions; one global handler turns them into responses using each exception's status_code; routes never catch domain exceptions.

Exceptions and handlers: ${JSON.stringify(catalog)}
Raise sites: ${JSON.stringify(raises.raises)}
Routes: ${JSON.stringify(routes.endpoints)}
Gaps found by comparison: ${JSON.stringify(gaps)}

Sections:
1. Summary: two or three sentences with the counts.
2. Coverage table: Exception | Raised in | Status code | Handled by.
3. Problems: for each gap, the severity (missing global handler or unhandled raise: high; route violation: high; never raised or stale handler: low), the file and line, and the exact fix.
4. Health: CLEAN, GOOD, NEEDS_WORK, or BROKEN.
Report only problems that appear in the data above.`,
  { label: 'report', phase: 'Report', effort: 'medium' },
)

return { report, gaps }

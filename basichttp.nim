import asynchttpserver,
       asyncnet,
       asyncdispatch,
       json,
       db_postgres,
       sequtils,
       strutils,
       times

type
  Response = (HttpCode, string, HttpHeaders)
  Routes = array[2, Route]
  Route = object
    path: string
    name: string
    meth: HttpMethod
    fn: proc (req: Request, headers: Httpheaders): Response {.gcsafe.}

  Endpoint = object
    id: int
    name: string
    path: string
    data: string
    created_at: int
    deleted_at: int

var
  db: DbConn
  routes {.threadvar.}: Routes

proc home(req: Request, headers: Httpheaders): Response =
  var ends: seq[Endpoint]

  # for row in db.rows(sql"SELECT id,name,path,data,created_at FROM endpoints WHERE deleted_at is NULL"):
    # ends.add(Endpoint(
    #   id: parseInt(row[0]),
    #   name: row[1],
    #   path: row[2],
    #   data: row[3],
    #   created_at: parseInt(row[4])
    # ))

  let row = db.getRow(sql"SELECT id,name,path,data,created_at FROM endpoints LIMIT 1")
  ends.add(Endpoint(
    id: parseInt(row[0]),
    name: row[1],
    path: row[2],
    data: row[3],
    created_at: parseInt(row[4])
  ))

  (Http200, $(%*ends), headers)

proc fourohfour(req: Request, headers: Httpheaders): Response =
  var data = $(%* {"error": 404})
  (Http404, data, headers)

proc parseRoute(req: Request): Route =
  for r in routes:
    if r.path == req.url.path and r.meth == req.reqMethod:
      return r
  return routes[0]

proc processRequest(req: Request): Response =
  let
    route = parseRoute(req)
    headers = newHttpHeaders([("Content-Type","application/json")])
  route.fn(req, headers)

proc asyncHttpHandler(req: Request) {.async.} =
  let (status, data, headers) = processRequest(req)
  await req.respond(status, data, headers)

when isMainModule:
  routes = [
    Route(path: "/404", name: "404",  meth: HttpGet, fn: fourohfour),
    Route(path: "/",    name: "root", meth: HttpGet, fn: home)
  ]

  db = open("localhost", "postgres", "", "misc")

  # db.exec(sql"CREATE TABLE endpoints (id serial primary key, name varchar(128) not null, path varchar(32) not null, data text not null, created_at integer not null, deleted_at integer null)")
  # db.exec(sql"INSERT INTO endpoints (name, path, data, created_at) VALUES (?, ?, ?, ?)", "the real test here", "/real", $(%*{"test":true}), getTime().toUnix)

  var server = newAsyncHttpServer()
  waitFor server.serve(Port(6000), asyncHttpHandler)

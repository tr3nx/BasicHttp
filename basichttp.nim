import asynchttpserver
     , asyncdispatch
     , strutils
     , json
     , uri
     , re

type
  Routes = array[4, Route]
  Route = object
    path: Regex
    name: string
    meth: HttpMethod
    fn: proc (req: Request, resp: Response, args: varargs[string]): Response {.gcsafe.}
  Response = object
    code: HttpCode
    data: string
    headers: Httpheaders

var
  routes {.threadvar.}: Routes

proc home(req: Request, resp: Response, arg: varargs[string]): Response =
  result = resp
  result.data = `$`(%* {"homepage": true})

proc item(req: Request, resp: Response, arg: varargs[string]): Response =
  result = resp
  let id = if arg[0] != "": parseInt(arg[0]) else: 0
  result.data = `$`(%*{"item": id})

proc fourohfour(req: Request, resp: Response, arg: varargs[string]): Response =
  result = resp
  result.data = `$`(%* {"error": 404})

proc asyncHttpHandler(req: Request) {.async.} =
  var
    resp = Response(code: Http200, headers: newHttpHeaders([("Content-Type","application/json")]))
    route: Route = routes[0]
    args: string

  if req.url.path == "/":
    route = routes[1]
  else:
    for r in routes[2..routes.len-1]:
      if r.meth != req.reqMethod: break

      var matches: array[1, string]
      if re.match(req.url.path, r.path, matches) and matches.len > 0:
        args = $matches[0]
        route = r

  resp = route.fn(req, resp, args)
  await req.respond(resp.code, `$`(%*resp.data), resp.headers)

when isMainModule:
  routes = [ Route(path: re("/404"), name: "404", meth: HttpGet, fn: fourohfour)
           , Route(path: re("/"), name: "root", meth: HttpGet, fn: home)
           , Route(path: re("/home"), name: "home", meth: HttpGet, fn: home)
           , Route(path: re("/items/([0-9]+)"), name: "item", meth: HttpGet, fn: item)
           ]

  var server = newAsyncHttpServer()
  waitFor server.serve(Port(6000), asyncHttpHandler)

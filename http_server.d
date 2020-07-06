import std.stdio, std.socket, core.thread, std.file, std.datetime, std.conv;
import std.array, std.algorithm, std.string;

class Handler : Thread{
  private Socket socket;

  this(){
    super(&run);
  }

  this(Socket socket){
    this.socket = socket;
    super(&run);
  }

  private void run(){
    char[2048] buffer;
    char[] buffer_response;
    auto lenght = socket.receive(buffer);
    string request = to!string(buffer[0 .. lenght]);
    string[] splited_request = request.split[0 .. 3];

    auto method = splited_request[0];
    auto path = splited_request[1];
    auto http_version = splited_request[2];

    if(!path.startsWith("/")){
      socket.shutdown(SocketShutdown.BOTH);
      auto curr_time = Clock.currTime(UTC());
      throw new Exception(curr_time.toString() ~ " [ ERROR ] Path must start with /");
    }

    if(path == "/") { path = "/index.html"; }
    auto final_path = "public_html" ~ path;

    writeln(Clock.currTime(UTC()).toString() ~ "[ INFO ] Client " ~ socket.hostName() ~
    " Path : " ~ path);

    if(!exists(final_path)){
      http_return("404 error: File not Found".dup, 404 , "Not Found", "text/plain");
      socket.shutdown(SocketShutdown.BOTH);
      return;
    }

    auto page_file = File(final_path, "r");
    auto buf = page_file.rawRead(new char[page_file.size()]);
    string[] splited_path = path.split(".");

    string[string] mimes = [
      "html" : "text/html;charset=utf-8",
      "png" : "image/png",
      "jpg" : "image/jpeg",
      "css" : "text/css",
      "gif" : "image/gif",
      "js" : "text/javascript"
    ];

    auto my_mime_type = "application/binary";

    if(splited_path[splited_path.length-1] in mimes){
      my_mime_type = mimes[splited_path[splited_path.length-1]];
    }

    http_return(buf,200 , "OK", my_mime_type);

    page_file.close();
    socket.shutdown(SocketShutdown.BOTH);
  }

  private void http_return(char[] data, int status, string status_text,
                           string mime="application/binary"){

    string response = "HTTP/1.1 " ~ to!string(status) ~ " " ~ status_text ~ "\r\n";
    response ~= "Content-Type: " ~ mime ~ "\r\n";
    response ~= "Content-Length: " ~ to!string(data.length) ~ "\r\n\r\n";
    response ~= data;

    socket.send(response);
  }

}

void main(string[] args){

  if(args.length != 4){
    writeln("[ ERROR ] Wrong arguments. Close server...");
    return;
  }

  ushort port = to!ushort(args[1]);
  string public_html = args[3];
  string addr = args[2];

  auto listener = new Socket(AddressFamily.INET, SocketType.STREAM);
  listener.bind(new InternetAddress(addr.dup, port));
  listener.listen(10);

  writeln(Clock.currTime(UTC()).toString() ~ " [ INFO ] Server start => [ hostName : " ~
  listener.hostName() ~ " : localAddress : " ~ listener.localAddress().toAddrString() ~ " ]");

  bool isRunning = true;
  while(isRunning){
    auto client = listener.accept();
    auto curr_time = Clock.currTime(UTC());

    writeln(curr_time.toString() ~ " [ INFO ] Connected client => [ hostName : " ~
    client.hostName() ~ " : localAddress : " ~ client.localAddress().toAddrString() ~
    " : remoteAddress : " ~ client.remoteAddress().toAddrString() ~ " ]");

    auto t1 = new Handler(client);
    t1.isDaemon(false);
    t1.start();
  }
}

//// Minimal SMTP istemcisi — Erlang FFI üzerinden doğrudan SMTP konuşması.
//// Harici bağımlılık gerektirmez; gen_tcp + base64 kullanır.

@external(erlang, "smtp_ffi", "send")
pub fn send(
  host: String,
  port: Int,
  username: String,
  password: String,
  from: String,
  to: String,
  subject: String,
  html_body: String,
) -> Result(Nil, String)

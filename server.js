/**
 * Servidor local para o EcoChain Protocol Frontend
 *
 * Uso:  node server.js
 * URL:  http://localhost:3000
 *
 * Necessário porque a MetaMask não funciona com o protocolo file://
 * em alguns navegadores. Este servidor serve os arquivos do frontend
 * com os headers corretos para funcionamento do Web3.
 *
 * Porta customizável via variável de ambiente:
 *   PORT=8080 node server.js
 */

const http = require("http");
const fs   = require("fs");
const path = require("path");

const PORT = process.env.PORT || 3000;
const ROOT = path.join(__dirname, "frontend");

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js":   "application/javascript; charset=utf-8",
  ".css":  "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png":  "image/png",
  ".jpg":  "image/jpeg",
  ".svg":  "image/svg+xml",
  ".ico":  "image/x-icon",
  ".woff2":"font/woff2",
};

// Resolve o caminho real do arquivo, sanitizando path traversal
function resolveSafePath(reqUrl) {
  // Remove query string e fragmentos
  const urlPath = reqUrl.split("?")[0].split("#")[0];
  const decoded = decodeURIComponent(urlPath);
  const filePath = path.join(ROOT, decoded === "/" ? "index.html" : decoded);

  // Garante que o arquivo resolvido está dentro de ROOT (prevenção de path traversal)
  if (!filePath.startsWith(ROOT + path.sep) && filePath !== ROOT) {
    return null;
  }
  return filePath;
}

http.createServer((req, res) => {
  // Responde a requisições OPTIONS (preflight CORS)
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "Access-Control-Allow-Origin":  "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    });
    res.end();
    return;
  }

  if (req.method !== "GET") {
    res.writeHead(405, { "Content-Type": "text/plain" });
    res.end("Method Not Allowed");
    return;
  }

  const filePath = resolveSafePath(req.url);
  if (!filePath) {
    res.writeHead(403, { "Content-Type": "text/plain" });
    res.end("Forbidden");
    return;
  }

  const ext  = path.extname(filePath).toLowerCase();
  const mime = MIME[ext] || "application/octet-stream";

  fs.readFile(filePath, (err, data) => {
    if (err) {
      if (err.code === "ENOENT") {
        res.writeHead(404, { "Content-Type": "text/plain" });
        res.end("404 — Arquivo não encontrado: " + path.basename(filePath));
      } else {
        res.writeHead(500, { "Content-Type": "text/plain" });
        res.end("Erro interno do servidor.");
      }
      return;
    }

    res.writeHead(200, {
      "Content-Type":              mime,
      "Content-Length":            data.length,
      "Cache-Control":             "no-cache, no-store, must-revalidate",
      "Access-Control-Allow-Origin": "*",
      // Segurança básica para DApp Web3
      "X-Content-Type-Options":   "nosniff",
      "X-Frame-Options":          "SAMEORIGIN",
    });
    res.end(data);
  });

}).listen(PORT, "127.0.0.1", () => {
  console.log("\n╔══════════════════════════════════════════════╗");
  console.log("║   🌿 EcoChain Protocol — Servidor Local      ║");
  console.log("╠══════════════════════════════════════════════╣");
  console.log(`║   URL: http://localhost:${PORT}                  ║`);
  console.log("║   Para parar: Ctrl + C                        ║");
  console.log("╚══════════════════════════════════════════════╝\n");
});

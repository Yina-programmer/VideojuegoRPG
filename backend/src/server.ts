import 'dotenv/config';
import app from './app';

const PORT = parseInt(process.env.PORT ?? '3000', 10);

app.listen(PORT, () => {
  console.log(`[server] API corriendo en http://localhost:${PORT}`);
  console.log(`[server] Entorno: ${process.env.NODE_ENV ?? 'development'}`);
  console.log(`[server] Health check: http://localhost:${PORT}/health`);
});

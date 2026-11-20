declare global {
  namespace Express {
    interface Request {
      auth?: {
        sessionId: string;
        accountId: string;
        playerId: string;
        username: string;
        email: string;
      };
    }
  }
}

export {};

import jwt from 'jsonwebtoken';

export const authenticateAdmin = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Missing or invalid authorization header'
      });
    }

    const token = authHeader.substring(7);
    const secret = process.env.ADMIN_JWT_SECRET;

    if (!secret) {
      throw new Error('ADMIN_JWT_SECRET not configured');
    }

    const decoded = jwt.verify(token, secret);
    
    // Check if token has admin role
    if (!decoded.role || decoded.role !== 'admin') {
      return res.status(403).json({
        error: 'Forbidden',
        message: 'Insufficient permissions'
      });
    }

    req.admin = decoded;
    next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid token'
      });
    }
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Token expired'
      });
    }
    return res.status(500).json({
      error: 'Internal Server Error',
      message: error.message
    });
  }
};

// Utility to generate admin token (for testing/setup)
export const generateAdminToken = (adminId, expiresIn = '24h') => {
  const secret = process.env.ADMIN_JWT_SECRET;
  if (!secret) {
    throw new Error('ADMIN_JWT_SECRET not configured');
  }

  return jwt.sign(
    {
      id: adminId,
      role: 'admin',
      iat: Math.floor(Date.now() / 1000)
    },
    secret,
    { expiresIn }
  );
};

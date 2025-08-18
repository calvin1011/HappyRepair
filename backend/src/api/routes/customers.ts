import { Router } from 'express';

const router = Router();

router.get('/profile', (req, res) => {
  res.json({
    status: 'success',
    message: 'Customer profile endpoint - coming soon!',
  });
});

export default router;

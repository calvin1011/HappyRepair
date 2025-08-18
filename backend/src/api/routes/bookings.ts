import { Router } from 'express';

const router = Router();

router.post('/', (req, res) => {
  res.json({
    status: 'success',
    message: 'Create booking endpoint - coming soon!',
  });
});

export default router;

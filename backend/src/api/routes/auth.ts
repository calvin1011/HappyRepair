import { Router } from 'express';

const router = Router();

router.post('/register', (req, res) => {
  res.json({
    status: 'success',
    message: 'Registration endpoint - coming soon!',
    data: {
      phone: req.body.phone,
      userType: req.body.userType,
    },
  });
});

router.post('/login', (req, res) => {
  res.json({
    status: 'success',
    message: 'Login endpoint - coming soon!',
    data: {
      phone: req.body.phone,
      userType: req.body.userType,
    },
  });
});

export default router;

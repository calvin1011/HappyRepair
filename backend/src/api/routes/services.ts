import { Router } from 'express';
import { database } from '../../database';

const router = Router();

router.get('/', async (req, res) => {
  try {
    const { language = 'en' } = req.query;

    const query = `
      SELECT
        s.id,
        s.category,
        s.estimated_duration,
        COALESCE(st.name, s.name) as name,
        COALESCE(st.description, s.description) as description
      FROM services s
      LEFT JOIN service_translations st ON s.id = st.service_id AND st.language_code = $1
      WHERE s.is_active = true
      ORDER BY s.category, s.name
    `;

    const result = await database.query(query, [language]);

    res.json({
      status: 'success',
      data: {
        services: result.rows,
        language,
      },
    });

  } catch (error) {
    console.error('Get services error:', error);
    res.status(500).json({
      status: 'error',
      message: 'Failed to get services',
    });
  }
});

export default router;

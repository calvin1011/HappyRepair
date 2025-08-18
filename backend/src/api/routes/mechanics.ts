import { Router } from 'express';
import { database } from '../../database';

const router = Router();

router.get('/nearby', async (req, res) => {
  try {
    const { latitude, longitude, radius = 10 } = req.query;

    if (!latitude || !longitude) {
      return res.status(400).json({
        status: 'error',
        message: 'Latitude and longitude are required',
      });
    }

    // Use our PostGIS function to find nearby mechanics
    const query = `
      SELECT * FROM find_mechanics_within_radius($1, $2, $3)
    `;

    const result = await database.query(query, [
      parseFloat(latitude as string),
      parseFloat(longitude as string),
      parseInt(radius as string, 10)
    ]);

    res.json({
      status: 'success',
      data: {
        mechanics: result.rows,
        searchCriteria: {
          latitude: parseFloat(latitude as string),
          longitude: parseFloat(longitude as string),
          radius: parseInt(radius as string, 10),
        },
      },
    });

  } catch (error) {
    console.error('Nearby mechanics error:', error);
    res.status(500).json({
      status: 'error',
      message: 'Failed to find nearby mechanics',
    });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const query = `
      SELECT
        m.*,
        array_agg(DISTINCT s.name) FILTER (WHERE s.name IS NOT NULL) as services
      FROM mechanics m
      LEFT JOIN mechanic_services ms ON m.id = ms.mechanic_id
      LEFT JOIN services s ON ms.service_id = s.id
      WHERE m.id = $1 AND m.is_active = true
      GROUP BY m.id
    `;

    const result = await database.query(query, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        status: 'error',
        message: 'Mechanic not found',
      });
    }

    res.json({
      status: 'success',
      data: {
        mechanic: result.rows[0],
      },
    });

  } catch (error) {
    console.error('Get mechanic error:', error);
    res.status(500).json({
      status: 'error',
      message: 'Failed to get mechanic details',
    });
  }
});

export default router;

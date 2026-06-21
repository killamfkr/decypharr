package rclone

import (
	"context"
	"fmt"
	"net/http"
	"time"
)

func (m *Manager) waitForWebDAV(ctx context.Context) error {
	client := &http.Client{Timeout: 5 * time.Second}

	for attempt := 1; attempt <= 60; attempt++ {
		if ctx.Err() != nil {
			return ctx.Err()
		}

		req, err := http.NewRequestWithContext(ctx, http.MethodGet, m.webdavURL, nil)
		if err != nil {
			return err
		}

		resp, err := client.Do(req)
		if err == nil {
			_ = resp.Body.Close()
			if resp.StatusCode < 500 {
				m.logger.Info().
					Str("url", m.webdavURL).
					Int("status", resp.StatusCode).
					Msg("WebDAV is ready for rclone mount")
				return nil
			}
		}

		if attempt%10 == 0 {
			m.logger.Warn().
				Str("url", m.webdavURL).
				Int("attempt", attempt).
				Msg("Waiting for WebDAV before rclone mount")
		}

		time.Sleep(time.Second)
	}

	return fmt.Errorf("timed out waiting for webdav at %s", m.webdavURL)
}

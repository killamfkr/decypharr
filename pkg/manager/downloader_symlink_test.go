package manager

import (
	"testing"
	"time"
)

func TestSymlinkReadyTimeoutFor(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name      string
		fileCount int
		want      time.Duration
	}{
		{name: "zero uses default", fileCount: 0, want: symlinkReadyTimeout},
		{name: "small release uses default", fileCount: 1, want: symlinkReadyTimeout},
		{name: "medium release scales", fileCount: 100, want: 5 * time.Minute},
		{name: "large bluray scales", fileCount: 512, want: 25*time.Minute + 36*time.Second},
		{name: "huge release caps at mount wait", fileCount: 1000, want: symlinkMountWaitTimeout},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			if got := symlinkReadyTimeoutFor(tt.fileCount); got != tt.want {
				t.Fatalf("symlinkReadyTimeoutFor(%d) = %s, want %s", tt.fileCount, got, tt.want)
			}
		})
	}
}

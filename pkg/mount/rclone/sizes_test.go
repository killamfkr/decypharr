package rclone

import "testing"

func TestSizeForRC(t *testing.T) {
	tests := []struct {
		in     string
		want   int64
		wantOK bool
	}{
		{"16MB", 16 * 1024 * 1024, true},
		{"16M", 16 * 1024 * 1024, true},
		{"128MB", 128 * 1024 * 1024, true},
		{"10GB", 10 * 1024 * 1024 * 1024, true},
		{"10G", 10 * 1024 * 1024 * 1024, true},
		{"off", 0, false},
		{"", 0, false},
	}

	for _, tt := range tests {
		got, ok := sizeForRC(tt.in)
		if ok != tt.wantOK {
			t.Fatalf("sizeForRC(%q) ok = %v, want %v", tt.in, ok, tt.wantOK)
		}
		if got != tt.want {
			t.Fatalf("sizeForRC(%q) = %d, want %d", tt.in, got, tt.want)
		}
	}
}

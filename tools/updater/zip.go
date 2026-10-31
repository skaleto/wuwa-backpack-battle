package main

import (
	"archive/zip"
	"errors"
	"io"
	"os"
	"path"
	"path/filepath"
	"strings"
	"unicode"
)

const expandedLimit int64 = 6 * 1024 * 1024 * 1024

// Use Windows-safe paths on both platforms, including case collisions and ADS.
func safeRelative(name string) bool {
	if name == "" || len(name) > 1024 || strings.HasPrefix(name, "/") || strings.ContainsAny(name, "\\:") || path.Clean(name) != name {
		return false
	}
	for _, r := range name {
		if unicode.IsControl(r) {
			return false
		}
	}
	for _, part := range strings.Split(name, "/") {
		if part == "" || part == "." || part == ".." || strings.TrimRight(part, " .") != part {
			return false
		}
		base := strings.ToUpper(strings.SplitN(part, ".", 2)[0])
		if base == "CON" || base == "PRN" || base == "AUX" || base == "NUL" || (len(base) == 4 && (strings.HasPrefix(base, "COM") || strings.HasPrefix(base, "LPT")) && base[3] >= '1' && base[3] <= '9') {
			return false
		}
	}
	return true
}
func extractZip(archive, dest, root string) error {
	if !safeRelative(root) || strings.Contains(root, "/") {
		return errors.New("zip_root")
	}
	r, err := zip.OpenReader(archive)
	if err != nil {
		return errors.New("zip_open")
	}
	defer r.Close()
	if len(r.File) == 0 || len(r.File) > 50000 {
		return errors.New("zip_count")
	}
	names := map[string]bool{}
	files := map[string]bool{}
	total := uint64(0)
	// Validate every entry before creating anything, including implicit directories.
	for _, f := range r.File {
		name := strings.TrimSuffix(f.Name, "/")
		if !safeRelative(name) || (name != root && !strings.HasPrefix(name, root+"/")) || (name == root && !f.FileInfo().IsDir()) {
			return errors.New("zip_path")
		}
		if f.Mode()&os.ModeSymlink != 0 || (!f.Mode().IsRegular() && !f.FileInfo().IsDir()) {
			return errors.New("zip_type")
		}
		folded := strings.ToLower(name)
		if names[folded] {
			return errors.New("zip_duplicate")
		}
		names[folded] = true
		if !f.FileInfo().IsDir() {
			files[folded] = true
		}
		if f.UncompressedSize64 > uint64(expandedLimit) || total > uint64(expandedLimit)-f.UncompressedSize64 {
			return errors.New("zip_expanded_size")
		}
		total += f.UncompressedSize64
	}
	for name := range names {
		for parent := path.Dir(name); parent != "."; parent = path.Dir(parent) {
			if files[parent] {
				return errors.New("zip_file_directory_collision")
			}
		}
	}
	if err = os.Mkdir(dest, 0700); err != nil {
		return errors.New("stage_exists")
	}
	okay := false
	defer func() {
		if !okay {
			os.RemoveAll(dest)
		}
	}()
	for _, f := range r.File {
		name := strings.TrimSuffix(f.Name, "/")
		if name == root {
			continue
		}
		rel := strings.TrimPrefix(name, root+"/")
		target := filepath.Join(dest, filepath.FromSlash(rel))
		if f.FileInfo().IsDir() {
			if os.MkdirAll(target, 0755) != nil {
				return errors.New("zip_directory")
			}
			continue
		}
		if os.MkdirAll(filepath.Dir(target), 0755) != nil {
			return errors.New("zip_directory")
		}
		in, err := f.Open()
		if err != nil {
			return errors.New("zip_read")
		}
		mode := os.FileMode(0644)
		if f.Mode().Perm()&0111 != 0 {
			mode = 0755
		}
		out, err := os.OpenFile(target, os.O_WRONLY|os.O_CREATE|os.O_EXCL, mode)
		if err != nil {
			in.Close()
			return errors.New("zip_write")
		}
		count, copyErr := io.Copy(out, io.LimitReader(in, int64(f.UncompressedSize64)+1))
		closeErr := out.Close()
		in.Close()
		if copyErr != nil || closeErr != nil || uint64(count) != f.UncompressedSize64 {
			return errors.New("zip_content")
		}
	}
	okay = true
	return nil
}

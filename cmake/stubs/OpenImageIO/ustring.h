/* Stub OpenImageIO/ustring.h for Emscripten WASM builds.
 * Provides a minimal API-compatible ustring implementation so that
 * Blender code referencing OpenImageIO::ustring compiles without
 * the full OIIO library.
 *
 * The real OIIO ustring stores only a const char* pointer, making it
 * trivially copyable (required for std::atomic<UString> in BLI_ustring.hh).
 * This stub mirrors that design. */
#ifndef OPENIMAGEIO_USTRING_H
#define OPENIMAGEIO_USTRING_H

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <string>
#include <string_view>

namespace OpenImageIO {

namespace Strutil {

constexpr uint64_t strhash64(size_t len, const char *data)
{
  uint64_t h = 14695981039346656037ULL;
  for (size_t i = 0; i < len; ++i) {
    h ^= static_cast<uint64_t>(static_cast<unsigned char>(data[i]));
    h *= 1099511628211ULL;
  }
  return h;
}

} /* namespace Strutil */

/**
 * Trivially-copyable ustring stub. Stores only a const char* to an
 * empty string by default. For the WASM headless build this is
 * sufficient -- string interning is not needed.
 */
class ustring {
 public:
  constexpr ustring() noexcept : ptr_(nullptr) {}
  ustring(const char *str) : ptr_(str && str[0] ? _dup(str) : nullptr) {}
  ustring(const std::string &str) : ptr_(str.empty() ? nullptr : _dup(str.c_str())) {}
  ustring(std::string_view str)
      : ptr_(str.empty() ? nullptr : _dup(std::string(str).c_str()))
  {
  }

  const char *c_str() const noexcept
  {
    return ptr_ ? ptr_ : "";
  }
  const char *data() const noexcept
  {
    return c_str();
  }
  size_t size() const noexcept
  {
    return ptr_ ? std::strlen(ptr_) : 0;
  }
  size_t length() const noexcept
  {
    return size();
  }
  bool empty() const noexcept
  {
    return ptr_ == nullptr;
  }

  /* Return a const reference to a std::string. The real OIIO returns
   * a const ref to an internal global string table entry. We use
   * thread_local to hold the temporary, matching the lifetime
   * expectations of callers. This is not fully correct for concurrent
   * use, but sufficient for the headless WASM build where this path
   * is rarely exercised. */
  const std::string &string() const
  {
    thread_local std::string tls_str;
    tls_str = ptr_ ? ptr_ : "";
    return tls_str;
  }

  uint64_t hash() const noexcept
  {
    return ptr_ ? Strutil::strhash64(std::strlen(ptr_), ptr_) : 0;
  }

  bool operator==(const ustring &other) const noexcept
  {
    return ptr_ == other.ptr_ ||
           (ptr_ && other.ptr_ && std::strcmp(ptr_, other.ptr_) == 0);
  }
  bool operator!=(const ustring &other) const noexcept
  {
    return !(*this == other);
  }
  bool operator<(const ustring &other) const noexcept
  {
    if (!ptr_)
      return other.ptr_ != nullptr;
    if (!other.ptr_)
      return false;
    return std::strcmp(ptr_, other.ptr_) < 0;
  }

 private:
  const char *ptr_;

  /* Simple strdup-like helper. In a real build the string table would
   * handle lifetime; for the stub we leak intentionally -- these are
   * long-lived unique strings. */
  static const char *_dup(const char *s)
  {
    size_t len = std::strlen(s);
    char *buf = new char[len + 1];
    std::memcpy(buf, s, len + 1);
    return buf;
  }
};

} /* namespace OpenImageIO */

namespace std {
template<> struct hash<OpenImageIO::ustring> {
  size_t operator()(const OpenImageIO::ustring &s) const noexcept
  {
    return static_cast<size_t>(s.hash());
  }
};
} /* namespace std */

#endif /* OPENIMAGEIO_USTRING_H */

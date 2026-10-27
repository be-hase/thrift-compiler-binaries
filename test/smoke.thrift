// Sample IDL used by scripts/smoke-test.sh. Keep it to syntax that every
// supported compiler version (0.9.x and later) understands.

namespace java smoke
namespace py smoke
namespace go smoke
namespace cpp smoke

const i32 ANSWER = 42

enum Color {
  RED = 1,
  GREEN = 2,
}

struct Point {
  1: required i32 x,
  2: optional i32 y = 0,
  3: list<string> tags,
  4: map<string, Color> colors,
}

exception NotFound {
  1: string message,
}

service Geometry {
  Point shift(1: Point p, 2: i32 dx) throws (1: NotFound nf),
  oneway void ping(),
}

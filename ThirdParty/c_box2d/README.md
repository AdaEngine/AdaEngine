# box2d

Little wrap around [box2d](https://github.com/erincatto/box2d) library.

## How to use 

1. Add package as dependency to your project `.package("https://github.com/SpectralDragon/box2d-swift", .branch("main"))`
2. Add target `box2d` to your target
3. Add this code to your target:             

```swift
// For Swift 5.6
swiftSettings: [
    .unsafeFlags(["-Xfrontend", "-enable-cxx-interop"])
]

// For Swift 5.7 and higher
swiftSettings: [
    .unsafeFlags(["-Xfrontend", "-enable-experimental-cxx-interop"])
]
```

4. Enjoy!

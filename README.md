# MixStorage

Storage object for iOS simply.

Storage type can be File, NSUserDefaults and Keychain

## Installation

### Swift Package Manager

Open the following menu item in Xcode:

**File > Add Packages...**

In the **Search or Enter Package URL** search box enter this URL: 

```text
https://github.com/longminxiang/MixStorage.git
```

Then, select the dependency rule and press **Add Package**.

> 💡 For further reference on SPM, check its [official documentation](https://developer.apple.com/documentation/swift_packages/adding_package_dependencies_to_your_app).


## Usage

Add a PropertyWrapper to current property to make it storable.

    struct User: Codable {
        var id: Int
        var name: String

        static var `default`: Self { User(id: 0, name: "user0") }
    }

    struct Test {

        // Storage string.
        @MixStorable(wrappedValue: nil, key: .init("username_storage"))
        var username: String?

        // Storage codable struct.
        // If Keychain storaged the user, return it, else return default user.
        @MixStorable(wrappedValue: .default, key: .init("user_storage"), mode: .keychain)
        var user: User
    }


Only two powerful api you will use.

    // set
    MixStorage.set(.init("test_key1"), value: "testValue", mode: .file)

    // get
    let value = MixStorage.get(.init("test_key1"), valueType: String.self, mode: .file)

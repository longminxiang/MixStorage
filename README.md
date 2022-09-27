# MixStorage

Storage object for iOS simply.
Storage type can be File, NSUserDefaults and Keychain

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

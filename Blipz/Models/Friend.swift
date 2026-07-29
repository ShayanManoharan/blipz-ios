import Foundation

struct Friend: Decodable, Identifiable {
    let id: String
    let username: String
}

struct FriendsListResponse: Decodable {
    let friends: [Friend]
}

struct AddFriendRequest: Encodable {
    let friendUsername: String
}

struct AddFriendResponse: Decodable {
    let message: String
    let friendId: String
    let username: String
}

import Foundation

struct AddFriendRequest: Encodable {
    let friendUsername: String
}

struct AddFriendResponse: Decodable {
    let message: String
    let friendId: String
    let username: String
}

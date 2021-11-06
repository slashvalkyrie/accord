//
//  User.swift
//  User
//
//  Created by Evelyn on 2021-08-16.
//

import Foundation
import AppKit

final class User: Decodable, Identifiable, Hashable {
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
    
    var id: String
    var username: String
    var discriminator: String
    var avatar: String?
    var bot: Bool?
    var system: Bool?
    var mfa_enabled: Bool?
    var locale: String?
    var verified: Bool?
    var email: String?
    var flags: Int?
    var premium_type: NitroTypes?
    var public_flags: Int?
    var bio: String?
    var nick: String?
    var roleColor: String?
    var pfp: Data?
    
    func isMe() -> Bool { user_id == self.id }
    func loadPfp() {
        Networking<AnyDecodable>().image(url: URL(string: pfpURL(self.id, self.avatar))) { avatar in
            guard let avatar = avatar else { return }
            self.pfp = avatar.tiffRepresentation
        }
    }
    
    // MARK: - Relationships
    func addFriend(_ guild: String, _ channel: String) {
        let headers = Headers(
            userAgent: discordUserAgent,
            token: AccordCoreVars.shared.token,
            type: .PUT,
            discordHeaders: true,
            referer: "https://discord.com/channels/\(guild)/\(channel)"
        )
        Networking<AnyDecodable>().fetch(url: URL(string: "\(rootURL)/users/@me/relationships/\(id)"), headers: headers) { _ in }
    }
    func removeFriend(_ guild: String, _ channel: String) {
        let headers = Headers(
            userAgent: discordUserAgent,
            token: AccordCoreVars.shared.token,
            type: .DELETE,
            discordHeaders: true,
            referer: "https://discord.com/channels/\(guild)/\(channel)"
        )
        Networking<AnyDecodable>().fetch(url: URL(string: "\(rootURL)/users/@me/relationships/\(id)"), headers: headers) { _ in }
    }
    func block(_ guild: String, _ channel: String) {
        let headers = Headers(
            userAgent: discordUserAgent,
            token: AccordCoreVars.shared.token,
            bodyObject: ["type":2],
            type: .PUT,
            discordHeaders: true,
            referer: "https://discord.com/channels/\(guild)/\(channel)"
        )
        Networking<AnyDecodable>().fetch(url: URL(string: "\(rootURL)/users/@me/relationships/\(id)"), headers: headers) { _ in }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum NitroTypes: Int, Decodable {
    case none = 0
    case classic = 1
    case nitro = 2
}

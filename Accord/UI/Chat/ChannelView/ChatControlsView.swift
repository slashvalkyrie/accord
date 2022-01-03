//
//  ChatControlsView.swift
//  ChatControlsView
//
//  Created by evelyn on 2021-08-23.
//

import Foundation
import SwiftUI

struct ChatControls: View {
    @State var chatTextFieldContents: String = ""
    @State var pfps: [String: NSImage] = [:]
    @Binding var guildID: String
    @Binding var channelID: String
    @Binding var chatText: String
    @Binding var replyingTo: Message?
    @State var nitroless = false
    @State var emotes = false
    @State var fileImport: Bool = false
    @State var fileUpload: Data?
    @State var fileUploadURL: URL?
    @State var dragOver: Bool = false
    @State var pluginPoppedUp: [Bool] = []
    @Binding var users: [User]
    @StateObject var viewModel = ChatControlsViewModel()
    @State var typing: Bool = false
    weak var textField: NSTextField?

    fileprivate func uploadFile(temp: String, url: URL? = nil) {
        var request = URLRequest(url: URL(string: "\(rootURL)/channels/\(channelID)/messages")!)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let params: [String: String] = [
            "content": String(temp)
        ]
        request.addValue(AccordCoreVars.token, forHTTPHeaderField: "Authorization")
        var body = Data()
        let boundaryPrefix = "--\(boundary)\r\n"
        for key in params.keys {
            body.append(string: boundaryPrefix, encoding: .utf8)
            body.append(string: "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n", encoding: .utf8)
            body.append(string: "\(params["content"]!)\r\n", encoding: .utf8)
        }
        body.append(string: boundaryPrefix, encoding: .utf8)
        let mimeType = fileUploadURL?.mimeType()
        body.append(string: "Content-Disposition: form-data; name=\"file\"; filename=\"\(fileUploadURL?.pathComponents.last ?? "file.txt")\"\r\n", encoding: .utf8)
        body.append(string: "Content-Type: \(mimeType ?? "application/octet-stream") \r\n\r\n", encoding: .utf8)
        body.append(fileUpload!)
        body.append(string: "\r\n", encoding: .utf8)
        body.append(string: "--".appending(boundary.appending("--")), encoding: .utf8)
        request.httpBody = body
        URLSession.shared.dataTask(with: request, completionHandler: { (_: Data?, _: URLResponse?, _: Error?) in
        }).resume()
    }
    func send() {
        guard viewModel.textFieldContents != "" else { return }
        print("sending")
        messageSendQueue.async { [weak viewModel] in
            if viewModel?.textFieldContents == "/shrug" {
                DispatchQueue.main.async {
                    viewModel?.textFieldContents = #"¯\_(ツ)_/¯"#
                }
            }
            if fileUpload != nil {
                uploadFile(temp: viewModel?.textFieldContents ?? "")
                fileUpload = nil
                fileUploadURL = nil
                DispatchQueue.main.async {
                    viewModel?.textFieldContents = ""
                    viewModel?.textField?.becomeFirstResponder()
                }
            } else {
                if replyingTo != nil {
                    Request.ping(url: URL(string: "\(rootURL)/channels/\(channelID)/messages"), headers: Headers(
                        userAgent: discordUserAgent,
                        token: AccordCoreVars.token,
                        bodyObject: ["content": "\(String(viewModel?.textFieldContents ?? ""))", "allowed_mentions": ["parse": ["users", "roles", "everyone"], "replied_user": true], "message_reference": ["channel_id": channelID, "message_id": replyingTo?.id ?? ""]],
                        type: .POST,
                        discordHeaders: true,
                        referer: "https://discord.com/channels/\(guildID)/\(channelID)",
                        empty: true,
                        json: true
                    ))
                    replyingTo = nil
                    DispatchQueue.main.sync {
                        viewModel?.textFieldContents = ""
                        viewModel?.textField?.becomeFirstResponder()
                    }
                } else {
                    Request.ping(url: URL(string: "\(rootURL)/channels/\(channelID)/messages"), headers: Headers(
                        userAgent: discordUserAgent,
                        token: AccordCoreVars.token,
                        bodyObject: ["content": "\(String(viewModel?.textFieldContents ?? ""))"],
                        type: .POST,
                        discordHeaders: true,
                        empty: true,
                        json: true
                    ))
                    DispatchQueue.main.sync {
                        viewModel?.textFieldContents = ""
                        viewModel?.textField?.becomeFirstResponder()
                    }
                }
            }
            DispatchQueue.main.async {
                viewModel?.textFieldContents = ""
                viewModel?.textField?.becomeFirstResponder()
            }
        }
    }
    var body: some View {
        HStack { [unowned viewModel] in
            ZStack(alignment: .trailing) {
                VStack {
                    if !(viewModel.matchedUsers.isEmpty) || !(viewModel.matchedEmoji.isEmpty) || !(viewModel.matchedChannels.isEmpty) {
                        ForEach(Array(zip(viewModel.matchedUsers.prefix(10).indices, viewModel.matchedUsers.prefix(10))), id: \.1) { _, user in
                            Button(action: { [weak viewModel, weak user] in
                                if let range = viewModel?.textFieldContents.range(of: "@") {
                                    viewModel?.textFieldContents.removeSubrange(range.lowerBound..<viewModel!.textFieldContents.endIndex)
                                }
                                viewModel?.textFieldContents.append("<@!\(user?.id ?? "")>")
                            }, label: { [weak user] in
                                HStack {
                                    Attachment(pfpURL(user?.id, user?.avatar).appending("?size=24"), size: CGSize(width: 48, height: 48))
                                        .clipShape(Circle())
                                        .frame(width: 20, height: 20)
                                    Text(user?.username ?? "Unknown User")
                                    Spacer()
                                }
                            })
                            .buttonStyle(.borderless)
                            .padding(5)
                            .background(Color(NSColor.windowBackgroundColor))
                            .cornerRadius(10)
                        }
                        ForEach(viewModel.matchedEmoji.prefix(10), id: \.id) { emoji in
                            Button(action: { [weak viewModel, weak emoji] in
                                if let range = viewModel?.textFieldContents.range(of: ":") {
                                    viewModel?.textFieldContents.removeSubrange(range.lowerBound..<viewModel!.textFieldContents.endIndex)
                                }
                                guard let id = emoji?.id, let name = emoji?.name else { return }
                                viewModel?.textFieldContents.append("<\((emoji?.animated ?? false) ? "" : ""):\(name):\(id)>")
                            }, label: { [weak emoji] in
                                HStack {
                                    Attachment("https://cdn.discordapp.com/emojis/\(emoji?.id ?? "").png?size=80", size: CGSize(width: 48, height: 48))
                                        .frame(width: 20, height: 20)
                                    Text(emoji?.name ?? "Unknown Emote")
                                    Spacer()
                                }
                            })
                            .buttonStyle(.borderless)
                            .padding(5)
                            .background(Color(NSColor.windowBackgroundColor))
                            .cornerRadius(10)
                        }
                        ForEach(viewModel.matchedChannels.prefix(10), id: \.id) { channel in
                            Button(action: { [weak viewModel, weak channel] in
                                if let range = viewModel?.textFieldContents.range(of: "#") {
                                    viewModel?.textFieldContents.removeSubrange(range.lowerBound..<viewModel!.textFieldContents.endIndex)
                                }
                                guard let id = channel?.id else { return }
                                viewModel?.textFieldContents.append("<#\(id)>")
                            }, label: { [weak channel] in
                                HStack {
                                    Text(channel?.name ?? "Unknown Channel")
                                    Spacer()
                                }
                            })
                            .buttonStyle(.borderless)
                            .padding(5)
                            .background(Color(NSColor.windowBackgroundColor))
                            .cornerRadius(10)
                        }
                    }
                    HStack {
                        if #available(macOS 12.0, *) {
                            TextField(chatText, text: $viewModel.textFieldContents)
                                .onSubmit {
                                    typing = false
                                    send()
                                }
                        } else {
                            TextField(chatText, text: $viewModel.textFieldContents, onEditingChanged: { _ in
                            }, onCommit: {
                                typing = false
                                send()
                            })
                        }
                        Button(action: {
                            fileImport.toggle()
                        }) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        Button(action: {
                            nitroless.toggle()
                        }) {
                            Image(systemName: "rectangle.grid.3x2.fill")
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .popover(isPresented: $nitroless, content: {
                            NavigationLazyView(NitrolessView(chatText: $viewModel.textFieldContents).equatable())
                                .frame(width: 300, height: 400)
                        })
                        Button(action: {
                            emotes.toggle()
                        }) {
                            Text("🥺")
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .keyboardShortcut("e", modifiers: [.command])
                        .popover(isPresented: $emotes, content: {
                            NavigationLazyView(EmotesView(chatText: $viewModel.textFieldContents).equatable())
                                .frame(width: 300, height: 400)
                        })
                        HStack {
                            if fileUpload != nil {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(Color.secondary)
                            }
                            /*
                            if AccordCoreVars.plugins != [] {
                                ForEach(AccordCoreVars.plugins.enumerated().reversed().reversed(), id: \.offset) { offset, plugin in
                                    if pluginPoppedUp.indices.contains(offset) {
                                        Button(action: {
                                            pluginPoppedUp[offset].toggle()
                                        }) {
                                            Image(systemName: plugin.symbol)
                                        }
                                        .buttonStyle(BorderlessButtonStyle())
                                        .popover(isPresented: $pluginPoppedUp[offset], content: {
                                            NSViewWrapper(plugin.body ?? NSView())
                                                .frame(width: 200, height: 200)
                                        })
                                    }
                                }
                            }
                            */
                        }
                    }
                    .onAppear(perform: {
                        viewModel.cachedUsers = self.users
                    })
                    .onChange(of: users, perform: { value in
                        self.viewModel.cachedUsers = value
                    })
                    .onReceive(viewModel.$textFieldContents, perform: { [weak viewModel] _ in
                        if !(typing) && viewModel?.textFieldContents != "" {
                            messageSendQueue.async {
                                Request.ping(url: URL(string: "https://discord.com/api/v9/channels/\(channelID)/typing"), headers: Headers(
                                    userAgent: discordUserAgent,
                                    token: AccordCoreVars.token,
                                    type: .POST,
                                    discordHeaders: true,
                                    referer: "https://discord.com/channels/\(guildID)/\(channelID)"
                                ))
                            }
                            typing = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
                                typing = false
                            })
                        }
                        viewModel?.markdown()
                        textQueue.async {
                            viewModel?.checkText(guildID: guildID)
                        }
                    })
                }
                .onAppear(perform: {
                    viewModel.findView()
                    for _ in AccordCoreVars.plugins {
                        pluginPoppedUp.append(false)
                    }
                })
                .textFieldStyle(PlainTextFieldStyle())
                .fileImporter(isPresented: $fileImport, allowedContentTypes: [.data]) { result in
                    fileUpload = try! Data(contentsOf: try! result.get())
                    fileUploadURL = try! result.get()
                }
                .onDrop(of: ["public.file-url"], isTargeted: $dragOver) { providers -> Bool in
                    providers.first?.loadDataRepresentation(forTypeIdentifier: "public.file-url", completionHandler: { (data, _) in
                        if let data = data, let path = NSString(data: data, encoding: 4), let url = URL(string: path as String) {
                            fileUpload = try! Data(contentsOf: url)
                            fileUploadURL = url
                        }
                    })
                    return true
                }
            }
        }
    }
}

extension Data {
    mutating func append(string: String, encoding: String.Encoding) {
        if let data = string.data(using: encoding) {
            append(data)
        }
    }
}

final class ChatControlsViewModel: ObservableObject {

    @Published var matchedUsers = [User]()
    @Published var matchedChannels = [Channel]()
    @Published var matchedEmoji = [DiscordEmote]()
    @Published var textFieldContents: String = ""
    @Published var cachedUsers = [User]()
    weak var textField: NSTextField?
    var currentValue: String?
    var currentRange: Int?

    func checkText(guildID: String) {
        let mentions = textFieldContents.matches(for: #"(?<=@)(?:(?!\ ).)*"#)
        let channels = textFieldContents.matches(for: #"(?<=#)(?:(?!\ ).)*"#)
        let slashes = textFieldContents.matches(for: #"(?<=\/)(?:(?!\ ).)*"#)
        let emoji = textFieldContents.matches(for: #"(?<=:).*"#)
        if !(mentions.isEmpty) {
            let search = mentions[0]
            let matched = cachedUsers.filter { $0.username.lowercased().contains(search.lowercased()) }
            DispatchQueue.main.async { [weak self] in
                self?.matchedUsers = matched.removingDuplicates()
            }
        } else if !(channels.isEmpty) {
            let search = channels[0]
            let matches = ServerListView.folders.map { $0.guilds.compactMap { $0.channels?.filter { $0.name?.contains(search) ?? false } } }
            let joined: [Channel] = Array(Array(Array(matches).joined()).joined()).filter { $0.guild_id == guildID }
            print(joined)
            DispatchQueue.main.async { [weak self] in
                self?.matchedChannels = joined
            }
        } else if !(slashes.isEmpty) {
            // TODO: Slash command implementation here
        } else if !(emoji.isEmpty) {
            let key = emoji[0]
            let matched: [DiscordEmote] = Array(Emotes.emotes.values.joined()).filter { $0.name.lowercased().contains(key) }
            DispatchQueue.main.async { [weak self] in
                self?.matchedEmoji = matched
            }
        }
    }

    func findView() {
        AppKitLink<NSTextField>.introspect { [weak self] textField, _ in
            textField.allowsEditingTextAttributes = true
            self?.textField = textField
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                self?.textField?.becomeFirstResponder()
            })
        }
    }

    func markdown() {
        guard !textFieldContents.isEmpty else { return }
        textField?.allowsEditingTextAttributes = true
        let attributed = NSAttributedMarkdown.markdown(textFieldContents, font: textField?.font)
        textField?.attributedStringValue = attributed
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()

        return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }

    mutating func removeDuplicates() {
        self = self.removingDuplicates()
    }
}
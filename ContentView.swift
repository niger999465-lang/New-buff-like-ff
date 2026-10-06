import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var phase
    @StateObject private var auto = AutoLike.shared
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView {
            Tab("Buff Like", systemImage: "hand.thumbsup.fill") { ToolPage(kind: .like) }
            Tab("Info", systemImage: "person.text.rectangle.fill") { ToolPage(kind: .info) }
            Tab("Auto", systemImage: "alarm.fill") { AutoPage() }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            Link(destination: URL(string: "https://t.me/mh_nguyen")!) {
                Label("Cre: Nguyen Minh Huy · @mh_nguyen", systemImage: "paperplane.fill")
                    .font(.footnote.weight(.semibold))
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: phase) { _, new in
            if new == .active {
                Task { await auto.runIfDue() }
                if auto.enabled { auto.scheduleBackground() }
            }
        }
        .onReceive(tick) { _ in Task { await auto.runIfDue() } }
    }
}

enum Kind {
    case like, info
    var endpoint: Endpoint { self == .like ? .like : .info }
    var subtitle: String { self == .like ? "Nhập ID Free Fire để buff like" : "Nhập ID Free Fire để xem thông tin" }
    var button: String { self == .like ? "Buff Like" : "Xem thông tin" }
    var icon: String { self == .like ? "hand.thumbsup.fill" : "info.circle.fill" }
}

struct Header: View {
    let subtitle: String
    var body: some View {
        VStack(spacing: 10) {
            Image("Avatar")
                .resizable().scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.45), lineWidth: 1.5))
                .shadow(color: .purple.opacity(0.5), radius: 18)
            Text("Buff Like By Nguyen Minh Huy")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.top, 24)
    }
}

struct ResultCard: View {
    let title: String
    let rows: [(String, String)]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                HStack(alignment: .top) {
                    Text(r.0).foregroundStyle(.secondary).font(.subheadline)
                    Spacer(minLength: 12)
                    Text(r.1).font(.subheadline.weight(.medium))
                        .multilineTextAlignment(.trailing).textSelection(.enabled)
                }
                Divider().opacity(0.3)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }
}

struct ToolPage: View {
    let kind: Kind
    @AppStorage("uid") private var uid = ""
    @State private var loading = false
    @State private var rows: [(String, String)] = []
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Background()
            ScrollView {
                VStack(spacing: 20) {
                    Header(subtitle: kind.subtitle)
                    inputCard
                    if loading { ProgressView().controlSize(.large).padding() }
                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .padding(16).frame(maxWidth: .infinity)
                            .glassEffect(.regular.tint(.red.opacity(0.2)), in: .rect(cornerRadius: 22))
                    }
                    if !rows.isEmpty { ResultCard(title: kind.button, rows: rows) }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    var inputCard: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "number").foregroundStyle(.secondary)
                TextField("Nhập ID Free Fire", text: $uid)
                    .keyboardType(.numberPad).focused($focused)
                if !uid.isEmpty {
                    Button { uid = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .glassEffect(.regular, in: .capsule)

            Button { run() } label: {
                Label(kind.button, systemImage: kind.icon).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(kind == .like ? .pink : .blue)
            .controlSize(.large)
            .disabled(uid.trimmingCharacters(in: .whitespaces).isEmpty || loading)
        }
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    func run() {
        focused = false
        error = nil; rows = []; loading = true
        let id = uid.trimmingCharacters(in: .whitespaces)
        Task {
            do { rows = try await API.call(kind.endpoint, uid: id) }
            catch { self.error = error.localizedDescription }
            loading = false
        }
    }
}

struct AutoPage: View {
    @StateObject private var auto = AutoLike.shared
    @AppStorage("uid") private var uid = ""

    var body: some View {
        ZStack {
            Background()
            ScrollView {
                VStack(spacing: 20) {
                    Header(subtitle: "Tự động buff like mỗi ngày")
                    VStack(spacing: 14) {
                        Toggle(isOn: $auto.enabled) {
                            Label("Auto like lúc 05:00 sáng", systemImage: "alarm.fill")
                                .font(.headline)
                        }
                        .tint(.pink)
                        HStack {
                            Text("ID đang dùng").foregroundStyle(.secondary)
                            Spacer()
                            Text(uid.isEmpty ? "Chưa nhập (qua tab Buff Like)" : uid).fontWeight(.medium)
                        }
                        .font(.subheadline)
                        HStack {
                            Text("Lần chạy cuối").foregroundStyle(.secondary)
                            Spacer()
                            if let d = auto.lastRun {
                                Text(d, format: .dateTime.day().month().hour().minute()).fontWeight(.medium)
                            } else { Text("—") }
                        }
                        .font(.subheadline)
                        Button {
                            Task { await auto.run(uid: uid, auto: false) }
                        } label: {
                            Label("Chạy thử ngay", systemImage: "play.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .disabled(uid.isEmpty || auto.running)
                    }
                    .padding(18)
                    .glassEffect(.regular, in: .rect(cornerRadius: 28))

                    if auto.running { ProgressView().controlSize(.large) }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kết quả gần nhất").font(.headline)
                        Text(auto.lastResult).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: .rect(cornerRadius: 28))

                    Text("Lưu ý: iOS không cho app chạy ngầm đúng giờ tuyệt đối. App sẽ nhắc lúc 5h sáng, tự chạy khi bạn mở app (sau 5h) hoặc khi iOS cho phép chạy nền. Mỗi ngày chỉ chạy 1 lần.")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                }
                .padding(20)
            }
        }
    }
}

struct Background: View {
    @State private var move = false
    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.03, blue: 0.10).ignoresSafeArea()
            Circle().fill(.purple).frame(width: 300).blur(radius: 90)
                .offset(x: move ? -90 : 80, y: move ? -240 : -160)
            Circle().fill(.pink).frame(width: 260).blur(radius: 90)
                .offset(x: move ? 110 : -60, y: move ? 120 : 220)
            Circle().fill(.blue).frame(width: 240).blur(radius: 90)
                .offset(x: move ? -100 : 100, y: move ? 300 : 180)
        }
        .ignoresSafeArea()
        .onAppear { withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) { move = true } }
    }
}

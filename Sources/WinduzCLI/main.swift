import ArgumentParser
import Foundation
import WinduzCore

func absolutePath(_ input: String) -> String {
    let expanded = (input as NSString).expandingTildeInPath
    if expanded.hasPrefix("/") {
        return (expanded as NSString).standardizingPath
    }
    let cwd = FileManager.default.currentDirectoryPath
    return ((cwd as NSString).appendingPathComponent(expanded) as NSString).standardizingPath
}

struct Winduz: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "wz",
        abstract: "Manage Winduz favorites and open directories in Ghostty+tmux.",
        subcommands: [Add.self, List.self, Remove.self, Open.self, Touch.self, Visit.self, Top.self],
        defaultSubcommand: List.self
    )
}

extension Winduz {
    struct Add: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Add a favorite (defaults to current directory).")

        @Argument(help: "Directory path. Defaults to current directory.")
        var path: String?

        @Option(name: .shortAndLong, help: "Display name. Defaults to last path component.")
        var name: String?

        func run() throws {
            let resolved = absolutePath(path ?? FileManager.default.currentDirectoryPath)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir), isDir.boolValue else {
                throw ValidationError("not a directory: \(resolved)")
            }
            let displayName = name ?? (resolved as NSString).lastPathComponent
            let fav = try Store.shared.add(name: displayName, path: resolved)
            print("added \(fav.name) → \(fav.path)")
        }
    }

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "ls", abstract: "List favorites.")

        @Flag(name: .long, help: "Output as tab-separated name<TAB>path (for piping to fzf/awk).")
        var tab: Bool = false

        func run() {
            let favs = Store.shared.load()
            if favs.isEmpty {
                if !tab { print("(no favorites)") }
                return
            }
            if tab {
                for fav in favs { print("\(fav.name)\t\(fav.path)") }
            } else {
                let width = favs.map { $0.name.count }.max() ?? 0
                for fav in favs {
                    print("\(fav.name.padding(toLength: width, withPad: " ", startingAt: 0))  \(fav.path)")
                }
            }
        }
    }

    struct Remove: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "rm", abstract: "Remove a favorite by name or path.")

        @Argument(help: "Name or path of favorite to remove.")
        var query: String

        func run() throws {
            let removed = try Store.shared.remove(matching: query)
            print("removed \(removed.name) → \(removed.path)")
        }
    }

    struct Touch: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Mark a favorite as recently used (updates ordering).")

        @Argument(help: "Favorite name or path.")
        var query: String

        func run() {
            if let fav = Store.shared.find(matching: query) {
                Store.shared.touch(path: fav.path)
            } else {
                Store.shared.touch(path: absolutePath(query))
            }
        }
    }

    struct Open: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Open a favorite (or arbitrary path) in Ghostty+tmux.")

        @Argument(help: "Favorite name, favorite path, or arbitrary directory path.")
        var query: String

        func run() throws {
            let path: String
            if let fav = Store.shared.find(matching: query) {
                path = fav.path
            } else {
                let resolved = absolutePath(query)
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir), isDir.boolValue else {
                    throw ValidationError("no favorite '\(query)' and not a directory: \(resolved)")
                }
                path = resolved
            }
            Launcher.openPath(path)
        }
    }
}

extension Winduz {
    struct Visit: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Record a visited directory (for chpwd hook).")

        @Argument(help: "Directory path visited.")
        var path: String

        func run() {
            let resolved = absolutePath(path)
            VisitLog.shared.append(path: resolved)
        }
    }

    struct Top: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Show top visited directories by frecency.")

        @Option(name: .shortAndLong, help: "Max entries to show.")
        var limit: Int = 20

        func run() {
            let top = VisitLog.shared.topPaths(limit: limit)
            if top.isEmpty { print("(no visits recorded)"); return }
            for (path, score) in top {
                print(String(format: "%6.2f  %@", score, path))
            }
        }
    }
}

Winduz.main()

import ArgumentParser
import KripkeStructure
import KripkeStructureViews
import Foundation

@main
public struct ModelExtract: ParsableCommand {

    enum OutputFormats: String, Hashable, Codable, Sendable, EnumerableFlag {

        case graphviz
        case nuxmv

        static func help(for value: ModelExtract.OutputFormats) -> ArgumentHelp? {
            switch value {
            case .graphviz:
                return "Outputs an <identifier>.gz file."
            case .nuxmv:
                return "Outputs an <identifier>.smv file."
            }
        }

        static func name(for _: ModelExtract.OutputFormats) -> NameSpecification {
            return [.short, .long]
        }

        var viewFactory: AnyKripkeStructureViewFactory {
            switch self {
            case .graphviz:
                return AnyKripkeStructureViewFactory(GraphVizKripkeStructureViewFactory())
            case .nuxmv:
                return AnyKripkeStructureViewFactory(NuSMVKripkeStructureViewFactory())
            }
        }

    }

    @Flag(help: "Does <kripke-structures> contain clock expressions?")
    var timed: Bool = false

    @Flag(help: "The formats to output.")
    var formats: [OutputFormats] = [.graphviz]

    @Option(
        name: [.short],
        help: ArgumentHelp(
            "The directory to store the newly generated models.",
            valueName: "output-directory"
        )
    )
    var outputDirectory: String = "models"

    @Argument(
        help: ArgumentHelp(
            "The filepath to the sqlite database containing the Kripke structure.",
            valueName: "kripke-structure"
        ),
        completion: .file()
    )
    var kripkeStructures: [String]

    public init() {}

    public mutating func run() throws {
        guard !formats.isEmpty else { throw ValidationError("Output format cannot be empty.") }
        let urls = kripkeStructures.map { URL(fileURLWithPath: $0, isDirectory: false) }
        let structures = try urls.map { try SQLiteKripkeStructure(readingAt: $0) }
        let fileManager = FileManager.default
        let outputURL = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)
        guard fileManager.changeCurrentDirectoryPath(outputURL.path) else {
            throw ValidationError("Unable to change working directory to \(outputURL.path)")
        }
        let viewFactory = AggregateKripkeStructureViewFactory(factories: Set(formats).map(\.viewFactory))
        for structure in structures {
            let view = viewFactory.make(identifier: structure.identifier)
            try view.generate(store: structure, usingClocks: timed)
        }
    }

}

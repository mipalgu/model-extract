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

    @Flag(help: "Does <kripke-structure> contain clock expressions?")
    var timed: Bool = false

    @Flag(help: "The formats to output.")
    var formats: [OutputFormats] = [.graphviz]

    @Argument(help: "The filepath to the sqlite database containing the Kripke structure.")
    var kripkeStructure: String

    @Option(name: [.short, .long], help: "The directory to store the newly generated models.")
    var outputDirectory: String = "models"

    public init() {}

    public mutating func run() throws {
        guard !formats.isEmpty else { throw ValidationError("Output format cannot be empty.") }
        let url = URL(fileURLWithPath: kripkeStructure, isDirectory: false)
        let structure = try SQLiteKripkeStructure(readingAt: url)
        let fm = FileManager.default
        let outputURL = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        try fm.createDirectory(at: outputURL, withIntermediateDirectories: true)
        guard fm.changeCurrentDirectoryPath(outputURL.path) else {
            throw ValidationError("Unable to change working directory to \(outputURL.path)")
        }
        let viewFactory = AggregateKripkeStructureViewFactory(factories: Set(formats).map(\.viewFactory))
        let view = viewFactory.make(identifier: structure.identifier)
        try view.generate(store: structure, usingClocks: timed)
    }

}

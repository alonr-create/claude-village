import SpriteKit

struct VillageLayout {
    // House positions in the village (scene coordinates, center = 0,0)
    static let houses: [(project: ProjectID, position: CGPoint)] = [
        (.matzpenLeosher,     CGPoint(x: -400, y:  200)),
        (.dekelLeprisha,      CGPoint(x: -400, y: -200)),
        (.alonDev,            CGPoint(x:  400, y:  200)),
        (.alizaHamefarsement, CGPoint(x:  400, y: -200)),
        (.hodaatBoker,        CGPoint(x:    0, y:  400)),
        (.appGames,           CGPoint(x:    0, y: -400)),
    ]

    static let villageCenter = CGPoint.zero

    // Roads connect houses through the center
    static let roadPaths: [(from: ProjectID, to: ProjectID)] = [
        (.matzpenLeosher, .alonDev),
        (.dekelLeprisha, .alizaHamefarsement),
        (.hodaatBoker, .appGames),
        (.matzpenLeosher, .dekelLeprisha),
        (.alonDev, .alizaHamefarsement),
        (.matzpenLeosher, .hodaatBoker),
        (.alonDev, .hodaatBoker),
        (.dekelLeprisha, .appGames),
        (.alizaHamefarsement, .appGames),
    ]

    static func position(for project: ProjectID) -> CGPoint {
        houses.first(where: { $0.project == project })?.position ?? .zero
    }

    // Scene dimensions
    static let sceneSize = CGSize(width: 2000, height: 1500)
    static let houseSize = CGSize(width: 130, height: 110)
    static let crabSize = CGSize(width: 32, height: 26)

    // Camera bounds
    static let minZoom: CGFloat = 0.4
    static let maxZoom: CGFloat = 2.0
}

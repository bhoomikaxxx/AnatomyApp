import Observation

@MainActor
@Observable
final class TimelineChatContext {
    static let dextrocardiaDescription = """
    Dextrocardia is a congenital cardiac positional abnormality in which the heart is located predominantly     on the right side of the chest with the apex pointing right. It results from abnormal cardiac looping     during early embryonic development. It may occur in isolation or together with situs inversus,     heterotaxy, or other congenital heart defects.
    """

    var selectedAge = "18 days"
    var developmentalDescription = """
    The cardiogenic area forms near the head end of the embryo. Cardiac precursor cells begin organising,     and primitive blood vessels start developing around the embryo.
    """
}

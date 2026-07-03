import XCTest
@testable import TextLensCore

final class SelectionActionPlanTests: XCTestCase {
    func testTranslateActionShowsResultPanelAndLoadsOnlyTranslation() {
        let plan = SelectionActionPlan.plan(for: .translate)

        XCTAssertTrue(plan.showsResultPanel)
        XCTAssertTrue(plan.loadsTranslation)
        XCTAssertFalse(plan.loadsExplanation)
    }

    func testExplainActionShowsResultPanelAndLoadsOnlyExplanation() {
        let plan = SelectionActionPlan.plan(for: .explain)

        XCTAssertTrue(plan.showsResultPanel)
        XCTAssertFalse(plan.loadsTranslation)
        XCTAssertTrue(plan.loadsExplanation)
    }

    func testDefaultTipActionsOnlyIncludeTranslateAndExplain() {
        XCTAssertEqual(SelectionAction.defaultTipActions, [.translate, .explain])
    }
}

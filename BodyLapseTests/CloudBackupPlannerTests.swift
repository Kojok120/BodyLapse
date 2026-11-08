import Foundation
import Testing
@testable import BodyLapse

struct CloudBackupPlannerTests {

    private let legacyDate = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func testFirstBackupProceeds() {
        let decision = CloudBackupPlanner.decide(cloud: .init(), local: .init(), localEarliestPhotoDate: nil, force: false)
        #expect(decision == .proceed)
    }

    @Test
    func testSameLineageProceedsOtherwiseNeedsDecision() {
        let cloud = CloudBackupPlanner.CloudSnapshot(manifestTag: "t1")
        var local = CloudBackupPlanner.LocalState()
        #expect(CloudBackupPlanner.decide(cloud: cloud, local: local, localEarliestPhotoDate: .distantPast, force: false) == .needsDecision(.otherBackup))
        local.manifestTag = "t1"
        #expect(CloudBackupPlanner.decide(cloud: cloud, local: local, localEarliestPhotoDate: nil, force: false) == .proceed)
        local.manifestTag = "t0"
        #expect(CloudBackupPlanner.decide(cloud: cloud, local: local, localEarliestPhotoDate: nil, force: false) == .needsDecision(.otherBackup))
        #expect(CloudBackupPlanner.decide(cloud: cloud, local: local, localEarliestPhotoDate: nil, force: true) == .proceed)
    }

    @Test
    func testLegacyMigrationHeuristic() {
        let cloud = CloudBackupPlanner.CloudSnapshot(legacyBackupDate: legacyDate)
        let local = CloudBackupPlanner.LocalState()
        // バックアップより前の写真がある = 同じ端末
        #expect(CloudBackupPlanner.decide(cloud: cloud, local: local, localEarliestPhotoDate: legacyDate.addingTimeInterval(-1), force: false) == .proceed)
        // 写真がバックアップより後だけ、または無い = まっさらな端末
        #expect(CloudBackupPlanner.decide(cloud: cloud, local: local, localEarliestPhotoDate: legacyDate.addingTimeInterval(1), force: false) == .needsDecision(.legacyBackup))
        #expect(CloudBackupPlanner.decide(cloud: cloud, local: local, localEarliestPhotoDate: nil, force: false) == .needsDecision(.legacyBackup))
        // 復元・置き換えを選んだ旧バックアップの続き
        var acknowledged = local
        acknowledged.acknowledgedLegacyBackupDate = legacyDate
        #expect(CloudBackupPlanner.decide(cloud: cloud, local: acknowledged, localEarliestPhotoDate: nil, force: false) == .proceed)
    }

    @Test
    func testRecordNameIsStableAndDistinct() {
        let a = CloudBackupPlanner.recordName(forMediaPath: "photos/default/A.jpg")
        #expect(a == CloudBackupPlanner.recordName(forMediaPath: "photos/default/A.jpg"))
        #expect(a != CloudBackupPlanner.recordName(forMediaPath: "photos/side/A.jpg"))
        #expect(a.hasPrefix("m-"))
        #expect(a.count == 66)
    }

    @Test
    func testUploadAndDeletePlans() {
        let a = CloudBackupPlanner.MediaItem(path: "a", recordName: "ra", size: 1)
        let b = CloudBackupPlanner.MediaItem(path: "b", recordName: "rb", size: 1)
        let c = CloudBackupPlanner.MediaItem(path: "c", recordName: "rc", size: 1)
        #expect(CloudBackupPlanner.mediaToUpload(current: [a, b, c], alreadyUploaded: ["ra"]) == [b, c])
        #expect(CloudBackupPlanner.recordsToDelete(previous: [a, b], current: [b, c]) == ["ra"])
    }
}

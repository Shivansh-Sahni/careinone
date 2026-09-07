import Foundation
import Testing
@testable import CareCore

struct EdgeCaseTests {
    @Test func gatewayWireContract() throws {
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf:root.appendingPathComponent("Fixtures/gateway-mock-envelope.json"))
        let wire = try JSONDecoder().decode(ExtractionEnvelope.self,from:data)
        #expect(wire.schemaVersion == ProposalValidator.version)
        let source = Source(title:"Synthetic",kind:.typed,text:"Synthetic note: CBC ordered.",contentHash:"test")
        let claim = try wire.claims[0].claim(source:source,version:"mock")
        #expect(!claim.canonical); #expect(claim.subject == .unknown); #expect(claim.needsStrongReview)
    }
    @Test func dateOnlyPreservesLocalCivilDay() throws {
        let date = try #require(DateParser.parse("2026-09-07")); let parts = Calendar.current.dateComponents([.year,.month,.day],from:date)
        #expect(parts.year == 2026); #expect(parts.month == 9); #expect(parts.day == 7)
    }
    @Test func transcriptLocationsAreEvidenceValidated() throws {
        var source=Source(title:"Voice",kind:.voice,text:"First. CBC ordered",contentHash:"test")
        source.transcriptSegments=[TranscriptSegment(text:"First",startUTF16:0,lengthUTF16:5,seconds:0),TranscriptSegment(text:"CBC",startUTF16:7,lengthUTF16:3,seconds:4)]
        var c=Claim(sourceID:source.id,kind:.labTest,label:"CBC",quote:"CBC ordered"); c.transcriptSeconds=4
        try ProposalValidator.validate(c,source:source)
        c.transcriptSeconds=0; #expect(throws:CareError.self) { try ProposalValidator.validate(c,source:source) }
        source.workingText="Edited. CBC ordered"; #expect(LocalExtractor.transcriptLocation("CBC ordered",source:source) == nil)
    }
    @Test func ambiguousExactAliasesNeverAutoMerge() {
        var a=Entity(kind:.provider,label:"Dr A"); a.aliases=["Dr Smith"]
        var b=Entity(kind:.provider,label:"Dr B"); b.aliases=["Dr Smith"]
        let c=Claim(sourceID:UUID(),kind:.provider,label:"Dr Smith",quote:"Dr Smith")
        #expect(EntityResolver.candidates(for:c,in:[a,b]).allSatisfy { !$0.automatic })
    }
    @Test func localTestNameContinuesAcrossRecaps() throws {
        var state=CareState()
        let texts=["CBC ordered","CBC result available"]
        for (i,text) in texts.enumerated() { state.sources.append(Source(title:"Synthetic",kind:.typed,text:text,contentHash:text,eventAt:Date(timeIntervalSince1970:Double(100+i)*86400))) }
        let claims=try state.sources.flatMap(LocalExtractor.proposals); try Reconciler.accept(claims,into:&state)
        #expect(state.entities.count == 1); #expect(state.loops.count == 1); #expect(state.loops[0].status == .completed)
        Reconciler.deleteSource(state.sources[1].id,from:&state); #expect(state.loops[0].status == .open)
    }
    @Test func sourceConditionalityOverridesOptimisticModel() throws {
        let wire=try JSONDecoder().decode(WireProposal.self,from:Data(#"{"kind":"labTest","label":"MRI","quote":"Consider MRI if needed","action":"ordered","subject":"patient","confidence":0.99,"conditional":false}"#.utf8))
        let source=Source(title:"Synthetic",kind:.typed,text:"Consider MRI if needed",contentHash:"test")
        let claim=try wire.claim(source:source,version:"test"); #expect(claim.conditional); #expect(claim.needsStrongReview)
    }
    @Test func aDateTodayDoesNotClaimItHasPassed() {
        let today=Calendar.current.startOfDay(for:Date())
        let loop=CareLoop(id:"test",entityID:UUID(),kind:.followUp,title:"Follow-up",stage:.requested,claimIDs:[],dueAt:today,precision:.exact,createdAt:today)
        #expect(!loop.timing(now:today.addingTimeInterval(12*3600)).contains("passed"))
    }
    @Test func deterministicSearchAndGroundedAnswer() async throws {
        var state=CareState(); try SyntheticDemo.load(into:&state)
        let hits=SearchEngine.search("metoprolol",state:state); #expect(!hits.isEmpty)
        let answer=try await LocalGroundedSynthesis().answer("metoprolol",state:state)
        #expect(answer.count == 3); #expect(answer.allSatisfy { state.source($0.sourceID)?.workingText.contains($0.quote) == true })
        #expect(answer.contains { $0.disputed })
        #expect(try await LocalGroundedSynthesis().answer("nonexistent",state:state).isEmpty)
    }
    @Test func briefPreservesConflictsAndSyntheticLabels() throws {
        var state=CareState(); try SyntheticDemo.load(into:&state)
        let text=BriefBuilder.text(state); #expect(text.contains("SYNTHETIC")); #expect(text.contains("25")); #expect(text.contains("50")); #expect(text.contains("RECORDS TO CLARIFY"))
    }
    @Test func syntheticDemoIsIdempotent() throws {
        var state=CareState(); try SyntheticDemo.load(into:&state); let count=state.sources.count
        try SyntheticDemo.load(into:&state); #expect(state.sources.count == count); #expect(state.sources.allSatisfy { $0.synthetic })
    }
    @Test func deletionPreservesUnrelatedEmptyEncounter() {
        var state=CareState(); let encounter=EncounterRecord(title:"Upcoming visit",date:nil,provider:"")
        state.encounters=[encounter]; let source=Source(title:"Unrelated note",kind:.typed,text:"A note",contentHash:"hash"); state.sources=[source]
        Reconciler.deleteSource(source.id,from:&state); #expect(state.encounters == [encounter])
    }
    @Test func safeBulkReviewExcludesUnknownHistoricalAndDisputedStates() {
        var claim=Claim(sourceID:UUID(),kind:.condition,label:"Synthetic",quote:"Synthetic"); claim.confidence=0.99
        for certainty in [Certainty.unknown,.notProvided,.historical,.disputed,.conditional,.uncertain] { claim.certainty=certainty; #expect(claim.needsStrongReview) }
        claim.certainty = .reported; #expect(!claim.needsStrongReview)
    }
    @Test func codedResultClosesMatchingTestWithoutMergingEntityKinds() throws {
        var state=CareState()
        let orderSource=Source(title:"Order",kind:.fhir,text:"CBC ordered",contentHash:"order",eventAt:Date(timeIntervalSince1970:100))
        let resultSource=Source(title:"Result",kind:.fhir,text:"CBC final",contentHash:"result",eventAt:Date(timeIntervalSince1970:200))
        state.sources=[orderSource,resultSource]
        var order=Claim(sourceID:orderSource.id,kind:.labTest,label:"CBC",quote:orderSource.workingText); order.action = .ordered; order.code="58410-2"; order.codeSystem="http://loinc.org"; order.eventAt=orderSource.eventAt
        var result=Claim(sourceID:resultSource.id,kind:.resultType,label:"CBC",quote:resultSource.workingText); result.action = .resultAvailable; result.code=order.code; result.codeSystem=order.codeSystem; result.eventAt=resultSource.eventAt
        try Reconciler.accept([order,result],into:&state)
        #expect(state.entities.count == 2); #expect(state.loops.count == 1); #expect(state.loops[0].status == .completed)
        #expect(state.relations.contains { $0.from == result.id && $0.kind == .resultOf })
        Reconciler.deleteSource(resultSource.id,from:&state); #expect(state.loops[0].status == .open)
    }
    @Test func fhirNonActiveMedicationAndAppointmentStatusesStayHonest() throws {
        func parse(_ type:String,_ status:String) throws -> Claim {
            let object:[String:Any] = ["resourceType":type,"status":status,"description":"Synthetic appointment","medicationCodeableConcept":["text":"Synthetic medicine"],"start":"2026-12-01T10:00:00Z"]
            return try FHIRImporter.parse(JSONSerialization.data(withJSONObject:object),sourceID:UUID()).claims[0]
        }
        #expect(try parse("MedicationStatement","active").action == .taking)
        for status in ["intended","on-hold","unknown","not-taken","entered-in-error"] { #expect(try parse("MedicationStatement",status).action != .taking) }
        #expect(try parse("MedicationStatement","not-taken").negated)
        #expect(try parse("MedicationStatement","intended").conditional)
        #expect(try parse("Appointment","cancelled").action == .dismissed)
        #expect(try parse("Appointment","fulfilled").certainty == .historical)
        #expect(try parse("Appointment","proposed").conditional)
    }
    @Test func unclassifiedFHIRServiceRequiresCategoryReview() throws {
        let data=Data(#"{"resourceType":"ServiceRequest","status":"active","intent":"order","code":{"text":"Some service"}}"#.utf8)
        let claim=try FHIRImporter.parse(data,sourceID:UUID()).claims[0]
        #expect(claim.kind == .other); #expect(claim.needsStrongReview)
    }
    @Test func syntheticFHIRBundleProposesAndLinksOnlyAfterReview() throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data=try Data(contentsOf:root.appendingPathComponent("Fixtures/synthetic-patient.fhir.json"))
        var source=Source(title:"Synthetic FHIR",kind:.fhir,text:String(decoding:data,as:UTF8.self),contentHash:"fixture")
        let imported=try FHIRImporter.parse(data,sourceID:source.id); source.workingText=imported.text
        var state=CareState(); state.sources=[source]; state.claims=imported.claims
        #expect(state.claims.allSatisfy { !$0.canonical }); #expect(state.entities.isEmpty)
        try Reconciler.accept(imported.claims,into:&state)
        #expect(state.loops.count == 1); #expect(state.loops[0].status == .completed)
        #expect(state.claims.first { $0.kind == .appointment }?.subject == .patient)
    }
    @Test func appointmentCaptureDateIsNotAnAppointmentDate() throws {
        let now=Date(); let source=Source(title:"Recap",kind:.typed,text:"Appointment discussed",contentHash:"test",eventAt:now.addingTimeInterval(86400))
        var state=CareState(); state.sources=[source]; try Reconciler.accept(LocalExtractor.proposals(source),into:&state)
        #expect(state.upcomingAppointments(now:now).isEmpty)
    }
    @Test func remindersExcludeSupersededApproximateAndHistoricalAppointments() throws {
        let now=Date(); let due=now.addingTimeInterval(3*86400)
        let source=Source(title:"Synthetic appointment",kind:.manual,text:"Appointment details",contentHash:"test")
        var state=CareState(); state.sources=[source]; state.profile.notifications=true
        var a=Claim(sourceID:source.id,kind:.appointment,label:"Cardiology",quote:source.workingText); a.dueAt=due; a.duePrecision = .exact; a.eventAt=now; a.action = .scheduled
        try Reconciler.accept([a],into:&state)
        var replacement=a; replacement.id=UUID(); replacement.dueAt=due.addingTimeInterval(86400); replacement.supersedesID=a.id; replacement.userEdited=true
        try Reconciler.accept([replacement],into:&state)
        #expect(state.upcomingAppointments(now:now).map(\.id) == [replacement.id])
        #expect(ReminderPlanner.plan(state,now:now).map(\.id) == ["visit-" + replacement.id.uuidString])
        for index in state.claims.indices { state.claims[index].duePrecision = .approximate }
        #expect(ReminderPlanner.plan(state,now:now).isEmpty)
        for index in state.claims.indices { state.claims[index].duePrecision = .exact; state.claims[index].certainty = .historical }
        #expect(state.upcomingAppointments(now:now).isEmpty); #expect(ReminderPlanner.plan(state,now:now).isEmpty)
    }
}

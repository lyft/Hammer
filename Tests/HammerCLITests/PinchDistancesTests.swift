import HammerAgentCore
import Testing

struct PinchDistancesTests {
    @Test
    func zoomingInSpreadsTheFingersToTheDistance() {
        let distances = PinchDistances.of(scale: 4, distance: 200)

        #expect(distances.start == 50)
        #expect(distances.end == 200)
    }

    @Test
    func zoomingOutStartsAtTheDistance() {
        let distances = PinchDistances.of(scale: 0.25, distance: 200)

        #expect(distances.start == 200)
        #expect(distances.end == 50)
    }

    @Test(arguments: [0, -1, 1, Double.nan])
    func scaleThatDoesntZoomIsAProblem(scale: Double) {
        let problem = PinchDistances.problem(scale: scale, distance: 200)

        #expect(problem?.message.hasPrefix("Invalid scale") == true)
    }

    @Test(arguments: [0, -10, Double.nan])
    func distanceThatIsntPositiveIsAProblem(distance: Double) {
        let problem = PinchDistances.problem(scale: 2, distance: distance)

        #expect(problem?.message.hasPrefix("Invalid distance") == true)
    }

    @Test
    func zoomingScaleAndDistanceAreFine() {
        #expect(PinchDistances.problem(scale: 2, distance: 200) == nil)
        #expect(PinchDistances.problem(scale: 0.5, distance: 200) == nil)
    }
}

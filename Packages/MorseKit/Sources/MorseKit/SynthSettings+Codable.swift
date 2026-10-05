import Foundation

// Hand-written Codable so stored settings stay readable across app versions: any key that is
// missing (e.g. a setting added later) falls back to its default instead of failing the decode.

extension HFImpairments {
    private enum CodingKeys: String, CodingKey {
        case noiseEnabled, snrDB
        case fadingEnabled, fadingDepth, fadingRate
        case staticEnabled, staticRate, staticLevel
        case filterEnabled, filterBandwidth
        case distortionEnabled, distortionDrive
    }

    public init(from decoder: any Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        noiseEnabled = try c.decodeIfPresent(Bool.self, forKey: .noiseEnabled) ?? noiseEnabled
        snrDB = try c.decodeIfPresent(Double.self, forKey: .snrDB) ?? snrDB
        fadingEnabled = try c.decodeIfPresent(Bool.self, forKey: .fadingEnabled) ?? fadingEnabled
        fadingDepth = try c.decodeIfPresent(Double.self, forKey: .fadingDepth) ?? fadingDepth
        fadingRate = try c.decodeIfPresent(Double.self, forKey: .fadingRate) ?? fadingRate
        staticEnabled = try c.decodeIfPresent(Bool.self, forKey: .staticEnabled) ?? staticEnabled
        staticRate = try c.decodeIfPresent(Double.self, forKey: .staticRate) ?? staticRate
        staticLevel = try c.decodeIfPresent(Double.self, forKey: .staticLevel) ?? staticLevel
        filterEnabled = try c.decodeIfPresent(Bool.self, forKey: .filterEnabled) ?? filterEnabled
        filterBandwidth = try c.decodeIfPresent(Double.self, forKey: .filterBandwidth) ?? filterBandwidth
        distortionEnabled = try c.decodeIfPresent(Bool.self, forKey: .distortionEnabled) ?? distortionEnabled
        distortionDrive = try c.decodeIfPresent(Double.self, forKey: .distortionDrive) ?? distortionDrive
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(noiseEnabled, forKey: .noiseEnabled)
        try c.encode(snrDB, forKey: .snrDB)
        try c.encode(fadingEnabled, forKey: .fadingEnabled)
        try c.encode(fadingDepth, forKey: .fadingDepth)
        try c.encode(fadingRate, forKey: .fadingRate)
        try c.encode(staticEnabled, forKey: .staticEnabled)
        try c.encode(staticRate, forKey: .staticRate)
        try c.encode(staticLevel, forKey: .staticLevel)
        try c.encode(filterEnabled, forKey: .filterEnabled)
        try c.encode(filterBandwidth, forKey: .filterBandwidth)
        try c.encode(distortionEnabled, forKey: .distortionEnabled)
        try c.encode(distortionDrive, forKey: .distortionDrive)
    }
}

extension SynthSettings {
    private enum CodingKeys: String, CodingKey {
        case frequency, riseTime, volume, impairments, seed
    }

    public init(from decoder: any Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        frequency = try c.decodeIfPresent(Double.self, forKey: .frequency) ?? frequency
        riseTime = try c.decodeIfPresent(Double.self, forKey: .riseTime) ?? riseTime
        volume = try c.decodeIfPresent(Double.self, forKey: .volume) ?? volume
        impairments = try c.decodeIfPresent(HFImpairments.self, forKey: .impairments) ?? impairments
        seed = try c.decodeIfPresent(UInt64.self, forKey: .seed) ?? seed
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(frequency, forKey: .frequency)
        try c.encode(riseTime, forKey: .riseTime)
        try c.encode(volume, forKey: .volume)
        try c.encode(impairments, forKey: .impairments)
        try c.encode(seed, forKey: .seed)
    }
}

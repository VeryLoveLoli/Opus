import XCTest
@testable import Opus
@testable import OpusSwift
import AudioToolbox

final class OpusTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
//        XCTAssertEqual(Opus().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
    
    let musicPath = "/Users/CCH/Desktop/OpusTest/OpusTest/EGOIST - Euterpe.mp3"
    
    func testEncode() {
        
        let inPath = musicPath
        let outPath = NSHomeDirectory() + "/Documents/out.opus"
        
        print(outPath)
        
        let s = DispatchSemaphore(value: 0)
        
        var i = 0
        OpusSwift.encode(inPath, opusPath: outPath, clientDescription: AudioStreamBasicDescription.pcm(16000, bits: 16, channel: 1), type: .voice) { f in
            print(f)
            i += 1
        } complete: { b in
            print(b)
            print(i)
            
            s.signal()
        }
        
        s.wait()
    }
    
    func testDecode() {
        
        let inPath = NSHomeDirectory() + "/Documents/out.caf"
        let outPath = NSHomeDirectory() + "/Documents/out.opus"
        
        let s = DispatchSemaphore(value: 0)
        
        var i = 0
        
        OpusSwift.decode(inPath, opusPath: outPath) { f in
            print(f)
            i += 1
        } complete: { b in
            print(b)
            print(i)
            s.signal()
        }

        s.wait()
    }
}

extension AudioStreamBasicDescription {
    
    /**
     PCM音频流参数
     
     - parameter    sampleRate:     采样率
     - parameter    bits:           采样位数
     - parameter    channel:        声道
     - parameter    packetFrames:   包帧数
     */
    public static func pcm(_ sampleRate: Float64 = 44100.00, bits: UInt32 = 32, channel: UInt32 = 2, packetFrames: UInt32 = 1) -> AudioStreamBasicDescription {
        
        var description = AudioStreamBasicDescription.init()
        
        /// 类型
        description.mFormatID = kAudioFormatLinearPCM
        /// flags
        description.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
        /// 采样率
        description.mSampleRate = sampleRate
        /// 采样位数
        description.mBitsPerChannel = bits
        /// 声道
        description.mChannelsPerFrame = channel
        /// 每个包的帧数
        description.mFramesPerPacket = packetFrames
        /// 每个帧的字节数
        description.mBytesPerFrame = description.mBitsPerChannel / 8 * description.mChannelsPerFrame
        /// 每个包的字节数
        description.mBytesPerPacket = description.mBytesPerFrame * description.mFramesPerPacket
        
        return description
    }
}

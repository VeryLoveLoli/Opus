//
//  OpusSwift.swift
//  RCTP
//
//  Created by 韦烽传 on 2021/3/7.
//

import Foundation
import AudioToolbox
import Opus
import Print

/**
 Opus 音频加解码
 */
open class OpusSwift {
    
    public enum EncodeType {
        /// 语音
        case voice
        /// 音乐
        case music
        /// 低延迟
        case lowdelay
        
        var value: Int32 {
            
            switch self {
            case .voice:
                return OPUS_APPLICATION_VOIP
            case .music:
                return OPUS_APPLICATION_AUDIO
            default:
                return OPUS_APPLICATION_RESTRICTED_LOWDELAY
            }
        }
    }
    
    /**
     编码
     
     - parameter    pcmPath:                PCM路径
     - parameter    opusPath:               OPUS路径
     - parameter    clientDescription:      转换音频参数
     - parameter    type:                   编码类型
     - parameter    multiple:               倍数(帧时间2.5毫秒的倍数 2.5~120 毫秒，获取的帧数需整数，帧数=采样率X时间)
     - parameter    progress:               进度
     - parameter    complete:               成功或失败
     */
    public static func encode(_ pcmPath: String, opusPath: String, clientDescription: AudioStreamBasicDescription? = nil, type: EncodeType = .music, multiple: Int = 24, progress: @escaping (Float)->Void, complete: @escaping (Bool)->Void) {
        
        let queue = DispatchQueue(label: "\(Date().timeIntervalSince1970).encode.\(Self.self).serial")
        
        queue.async {
            
            /// 地址
            guard let url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, pcmPath as CFString, .cfurlposixPathStyle, false) else { complete(false); Print.error("CFURLCreateWithFileSystemPath Error"); return }
            
            /// 状态
            var status: OSStatus = noErr
            
            /// 获取文件句柄
            var file: ExtAudioFileRef?
            status = ExtAudioFileOpenURL(url, &file)
            guard status == noErr else { complete(false); Print.error("ExtAudioFileOpenURL \(status)"); return }
            
            /// 获取文件音频流参数
            var description = AudioStreamBasicDescription()
            var size = UInt32(MemoryLayout.stride(ofValue: description))
            status = ExtAudioFileGetProperty(file!, kExtAudioFileProperty_FileDataFormat, &size, &description)
            guard status == noErr else { complete(false); Print.error("ExtAudioFileGetProperty kExtAudioFileProperty_FileDataFormat \(status)"); return }
            
            /// 获取文件音频流帧数
            var numbersFrames: Int64 = 0
            var numbersFramesSize = UInt32(MemoryLayout.stride(ofValue: numbersFrames))
            status = ExtAudioFileGetProperty(file!, kExtAudioFileProperty_FileLengthFrames, &numbersFramesSize, &numbersFrames)
            guard status == noErr else { complete(false); Print.error("ExtAudioFileGetProperty kExtAudioFileProperty_FileLengthFrames \(status)"); return }
            
            /// 设置客户端音频流参数（数据转换成这个参数播放）
            var client = clientDescription
            if client != nil {
                status = ExtAudioFileSetProperty(file!, kExtAudioFileProperty_ClientDataFormat, UInt32(MemoryLayout.stride(ofValue: client)), &client)
                guard status == noErr else { complete(false); Print.error("ExtAudioFileSetProperty kExtAudioFileProperty_ClientDataFormat \(status)"); return }
                /// 转码率后的帧数
                numbersFrames = Int64(Float64(numbersFrames)/description.mSampleRate*client!.mSampleRate)
                description = client!
            }
            
            /// 创建编码器
            let opus = OpusSwift(Int(description.mSampleRate), channels: Int(description.mChannelsPerFrame), bitsPer: Int(description.mBitsPerChannel), multiple: multiple, type: type)
            
            /// 每个时间片帧数
            var inNumberFrames = UInt32(description.mSampleRate*0.0025*Float64(multiple))
            /// 时间片数
            var timeNumber = numbersFrames/Int64(inNumberFrames)
            
            /// 删除旧的OPUS文件
            do {
                try FileManager.default.removeItem(atPath: opusPath)
            } catch  {
                
            }
            
            /// OPUS文件
            let opusFile: UnsafeMutablePointer<FILE> = fopen(opusPath, "wb")
            
            /// 设置文件头
            fwrite(&description, MemoryLayout.stride(ofValue: description), 1, opusFile)
            fwrite(&timeNumber, 8, 1, opusFile)
            fwrite(&inNumberFrames, 4, 1, opusFile)
            
            /// 缓冲
            var bufferList = AudioBufferList()
            bufferList.mNumberBuffers = 1
            bufferList.mBuffers.mNumberChannels = description.mChannelsPerFrame
            bufferList.mBuffers.mDataByteSize = UInt32(inNumberFrames) * description.mBytesPerFrame
            bufferList.mBuffers.mData = calloc(Int(inNumberFrames), Int(description.mBytesPerFrame))
            
            /// 关闭
            func closeFile() {
                
                /// 关闭编码
                opus.close()
                /// 释放内存
                free(bufferList.mBuffers.mData!)
                /// 关闭文件
                ExtAudioFileDispose(file!)
                fclose(opusFile)
            }
            
            /// 帧数
            var ioNumberFrames = inNumberFrames
            
            /// 编码字节数
            var number: UInt16 = 0
            
            for i in 0..<timeNumber {
                
                progress(Float(i)/Float(timeNumber))
                
                /// 读取数据
                status = ExtAudioFileRead(file!, &ioNumberFrames, &bufferList)
                guard status == noErr else { Print.error("ExtAudioFileRead \(status)"); closeFile(); complete(false); return }
                guard ioNumberFrames == inNumberFrames else { Print.error("ioNumberFrames != inNumberFrames ioNumberFrames: \(ioNumberFrames) inNumberFrames: \(inNumberFrames)"); closeFile(); complete(false); return }
                
                var bytes = [UInt8](repeating: 0, count: Int(ioNumberFrames)*Int(description.mBytesPerFrame))
                memcpy(&bytes, bufferList.mBuffers.mData!, bytes.count)
                
                /// 编码
                guard let buffer = opus.encode(bytes) else { Print.error("opus_encode error"); closeFile(); complete(false); return }
                
                number = UInt16(buffer.count)
                
                /// 长度
                fwrite(&number, 2, 1, opusFile)
                /// 数据
                fwrite(buffer, 1, Int(number), opusFile)
            }
            
            progress(1)
            closeFile()
            complete(true)
        }
    }
    
    /**
     解码
     
     - parameter    pcmPath:                PCM路径
     - parameter    opusPath:               OPUS路径
     - parameter    clientDescription:      转换音频参数
     - parameter    type:                   PCM文件类型
     - parameter    progress:               进度
     - parameter    complete:               成功或失败
     */
    public static func decode(_ pcmPath: String, opusPath: String, clientDescription: AudioStreamBasicDescription? = nil, type: AudioFileTypeID = kAudioFileCAFType, progress: @escaping (Float)->Void, complete: @escaping (Bool)->Void) {
        
        let queue = DispatchQueue(label: "\(Date().timeIntervalSince1970).decode.\(Self.self).serial")
        
        queue.async {
            
            /// OPUS文件
            let opusFile: UnsafeMutablePointer<FILE> = fopen(opusPath, "rb")
            
            /// 获取文件音频流参数
            var description = AudioStreamBasicDescription()
            var count = fread(&description, 40, 1, opusFile)
            guard count == 1 else{ Print.error("fread AudioStreamBasicDescription error \(count)"); complete(false); return }
            
            /// 时间片数
            var timeNumber: Int64 = 0
            count = fread(&timeNumber, 8, 1, opusFile)
            guard count == 1 else{ Print.error("fread timeNumber error \(count)"); complete(false); return }
            
            /// 每个时间片帧数
            var inNumberFrames: UInt32 = 0
            count = fread(&inNumberFrames, 4, 1, opusFile)
            guard count == 1 else{ Print.error("fread inNumberFrames error \(count)"); complete(false); return }
            
            /// 地址
            guard let url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, pcmPath as CFString, .cfurlposixPathStyle, false) else { Print.error("CFURLCreateWithFileSystemPath error \(pcmPath)"); complete(false); return }
            
            /// 状态
            var status: OSStatus = noErr
            
            /// 文件句柄
            var file: ExtAudioFileRef?
            /// 文件标记
            let flags = AudioFileFlags.eraseFile
            /// 创建音频文件（文件头4096长度）
            status = ExtAudioFileCreateWithURL(url, type, &description, nil, flags.rawValue, &file)
            guard status == noErr else { Print.error("ExtAudioFileCreateWithURL error \(status)"); return }
            
            /// 设置客户端音频流参数（数据转换成这个参数写入）
            var client = clientDescription
            if client != nil {
                status = ExtAudioFileSetProperty(file!, kExtAudioFileProperty_ClientDataFormat, UInt32(MemoryLayout.stride(ofValue: client)), &client)
                guard status == noErr else { Print.error("ExtAudioFileSetProperty kExtAudioFileProperty_ClientDataFormat error \(status)"); complete(false); return }
                description = client!
            }
            
            /// 缓冲
            var bufferList = AudioBufferList()
            bufferList.mNumberBuffers = 1
            bufferList.mBuffers.mNumberChannels = description.mChannelsPerFrame
            bufferList.mBuffers.mDataByteSize = UInt32(inNumberFrames) * description.mBytesPerFrame
            bufferList.mBuffers.mData = calloc(Int(inNumberFrames), Int(description.mBytesPerFrame))
            
            /// 创建解码器
            let opus = OpusSwift(Int(description.mSampleRate), channels: Int(description.mChannelsPerFrame), bitsPer: Int(description.mBitsPerChannel))
            
            /// 关闭
            func closeFile() {
                
                /// 关闭解码
                opus.close()
                /// 释放内存
                free(bufferList.mBuffers.mData!)
                /// 关闭文件
                ExtAudioFileDispose(file!)
                fclose(opusFile)
            }
            
            for i in 0..<timeNumber {
                
                progress(Float(i)/Float(timeNumber))
                
                /// 字节数
                var bytesCount: UInt16 = 0
                count = fread(&bytesCount, 2, 1, opusFile)
                guard count == 1 else{ Print.error("fread bytesCount error \(count)"); closeFile(); complete(false); return }
                
                /// 数据
                var bytes = Array(repeating: UInt8(0), count: Int(bytesCount))
                count = fread(&bytes, 1, Int(bytesCount), opusFile)
                guard count == bytesCount else{ Print.error("fread bytes error \(count)"); closeFile(); complete(false); return }
                
                /// 解码
                guard let buffer = opus.decode(bytes) else { Print.error("opus_decode error"); closeFile(); complete(false); return }
                
                bufferList.mBuffers.mData?.copyMemory(from: buffer, byteCount: buffer.count)
                
                /// 写入文件
                status = ExtAudioFileWrite(file!, inNumberFrames, &bufferList)
                guard status == noErr else { Print.error("ExtAudioFileWrite error \(status)"); closeFile(); complete(false); return }
            }
            
            progress(1)
            closeFile()
            complete(true)
        }
    }
    
    /// 采样率
    public let sampleRate: Int
    /// 通道
    public let channels: Int
    /// 采样位数
    public let bitsPer: Int
    /// 帧数
    public let frameNumber: Int
    
    /// 编码器
    public let encoder: OpaquePointer
    /// 解码器
    public let decoder: OpaquePointer
    
    /**
     初始化
     
     - parameter    sampleRate:     采样率
     - parameter    channels:       通道数
     - parameter    bitsPer:        采样位数
     - parameter    multiple:       倍数(帧时间2.5毫秒的倍数 2.5~120 毫秒，获取的帧数需整数，帧数=采样率X时间)
     - parameter    type:           编码类型
     */
    public init(_ sampleRate: Int = 16000, channels: Int = 2, bitsPer: Int = 16, multiple: Int = 24, type: EncodeType = .music) {
        
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitsPer = bitsPer
        self.frameNumber = Int(Float64(sampleRate)*0.0025*Float64(multiple))
        
        encoder = opus_encoder_create(Int32(sampleRate), Int32(channels), type.value, nil)
        decoder = opus_decoder_create(Int32(sampleRate), Int32(channels), nil)
    }
    
    /**
     解码
     
     - parameter    bytes:  解码数据
     */
    open func decode(_ bytes: [UInt8]) -> [UInt8]? {
        
        let maxFrameSize = frameNumber * channels * bitsPer / 8
        
        var decodePacket = Array.init(repeating: opus_int16(0), count: Int(maxFrameSize))
        
        let code = opus_decode(decoder, bytes, opus_int32(bytes.count), &decodePacket, Int32(maxFrameSize), 0)
        
        if code <= 0 {
            
            return nil
        }
        else {
            
            return [UInt8](Data.init(bytes: decodePacket, count: Int(code) * channels * bitsPer / 8))
        }
    }
    
    /**
     编码
     帧数必须和设置的倍数一致：frameNumber = Int(Float64(sampleRate)*0.0025*Float64(multiple))
     字节数  bytesCount = frameNumber * channels * bitsPer / 8
     
     - parameter    bytes:  编码的帧数据
     */
    open func encode(_ bytes: [UInt8]) -> [UInt8]? {
        
        var code: Int32 = 0
        
        let maxFrameSize = frameNumber * channels * bitsPer / 8
        
        var encodePacket = [UInt8].init(repeating: 0, count: maxFrameSize)
        
        var data = Data(bytes: bytes, count: bytes.count)
        
        data.withUnsafeMutableBytes { (body: UnsafeMutableRawBufferPointer) -> Void in
            
            let bind = body.bindMemory(to: Int16.self)
            
            if let buffer = bind.baseAddress {
                
                code = opus_encode(encoder, buffer, Int32(frameNumber), &encodePacket, opus_int32(maxFrameSize))
            }
        }
        
        if code <= 0 {
            
            return nil
        }
        
        return [UInt8](encodePacket[0..<Int(code)])
    }
    
    /**
     关闭
     */
    open func close() {
        
        opus_encoder_destroy(encoder)
        opus_decoder_destroy(decoder)
    }
}

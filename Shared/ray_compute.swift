//
//  ray_compute.swift
//  fractal-raytracing
//
//  Created by yumeng on 2021/8/16.
//

import Foundation
import Metal

struct metal_sphere {
    var center: Vec3
    var radius: Float
}

struct metal_ray {
    var origin: Vec3
    var direction: Vec3
}

func ComputeTexture(_ win_width: Int, _ win_height: Int) -> CGImage{
    var image: CGImage?
    do{
        let device = MTLCreateSystemDefaultDevice()
        let metal_lib = device?.makeDefaultLibrary()
        let metal_func = metal_lib?.makeFunction(name: "compute_ray")
        let func_pso = try device?.makeComputePipelineState(function: metal_func!)
        
        // 设置command queue，command_buffer，compute_encoder
        let cmd_queue = device?.makeCommandQueue()
        let cmd_buff = cmd_queue?.makeCommandBuffer()
        let compute_encoder = cmd_buff?.makeComputeCommandEncoder()
        // 设置compute encoder的pipeline state和输入buffer，或者texture
        // 即将compute shader和输入的数据绑定（笔者的理解)
        compute_encoder?.setComputePipelineState(func_pso!)
        
        // 先创建metal输出的texture
        let texture_descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: MTLPixelFormat.rgba8Unorm,
            width: Int(win_width), height: Int(win_height),
            mipmapped: false)
        texture_descriptor.usage = MTLTextureUsage.shaderWrite
        texture_descriptor.textureType = MTLTextureType.type2D
        let texture = device?.makeTexture(descriptor: texture_descriptor)
        compute_encoder?.setTexture(texture, index: 0)
        // 设置hitlist
        var spheres = [metal_sphere]()
        spheres.append(
            metal_sphere(center:Vec3(x:0,y:0,z:0),
                         radius:1.0)
        )
        
//        let array_ptr = UnsafeRawPointer(&spheres)
        let array_size = MemoryLayout<metal_sphere>.size * spheres.count
        let sphere_buffer = device?.makeBuffer(
            bytes: spheres,
            length: array_size,
            options: MTLResourceOptions.storageModeShared)
        compute_encoder?.setBuffer(sphere_buffer, offset: 0, index: 0)
        
        let eye_position = [Vec3(x:1.0, y:0.0, z:0.0)]
        let eye_buffer = device?.makeBuffer(
            bytes: eye_position,
            length: MemoryLayout<Vec3>.size,
            options: MTLResourceOptions.storageModeShared)
        compute_encoder?.setBuffer(eye_buffer, offset:0, index:1)
        
        // 设置thread组织形式
        let grid_size = MTLSizeMake(win_width, win_height, 1)
        // metal 这个thread_group_size 应该怎样设置？
        // 参照 https://developer.apple.com/documentation/metal/calculating_threadgroup_and_grid_sizes
        let w = func_pso?.threadExecutionWidth
        let h = (func_pso?.maxTotalThreadsPerThreadgroup)! / w!
        let thread_group_size = MTLSizeMake(w!, h, 1)
        compute_encoder?.dispatchThreads(grid_size, threadsPerThreadgroup: thread_group_size)
        //  compute pass encoding结束
        compute_encoder?.endEncoding()
        
        // 执行command buffer
        cmd_buff?.commit()
        
        // 等待command buffer执行完成,一般可以GPU和CPU可以并行协作，这里现等待GPU完成工作
        cmd_buff?.waitUntilCompleted()
        // 这里还要暂停cpu线程，等待texture的填充完毕
        sleep(6)
        var imageBytes = [UInt8](
            repeating: 0,
            count: Int(win_width * win_height * 4))
        
        let region = MTLRegionMake2D(0, 0, win_width, win_height)
        texture!.getBytes(
            UnsafeMutableRawPointer(&imageBytes),
            bytesPerRow: win_width * 4,
            from: region,
            mipmapLevel: 0)
        // 返回texture信息
        let bitsPerComponent = 8
        let bitsPerPixel = 32
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        let providerRef = CGDataProvider(
            data:NSData(
                bytes: imageBytes,
                length: imageBytes.count))
        image = CGImage(
            width:win_width,
            height:win_height,
            bitsPerComponent:bitsPerComponent,
                            
            bitsPerPixel:bitsPerPixel,
            bytesPerRow:win_width * 4,
            space:rgbColorSpace,
            bitmapInfo:bitmapInfo,
            provider:providerRef!,
            decode:nil,
            shouldInterpolate:true,
            intent:CGColorRenderingIntent.defaultIntent)
        
    }
    catch {
        print("create function pipeline state failed")
    }
    return image!
}



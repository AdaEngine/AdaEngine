// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import GLSLangWrapper
import miniaudio
import SPIRV_Cross

glslang_initialize()
glslang_finalize()

var engine = ma_engine()
miniaudio.ma_engine_start(&engine)

var context: spvc_context?!
spvc_context_create(&context)


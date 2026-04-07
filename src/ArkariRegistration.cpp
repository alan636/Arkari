//===-- ArkariRegistration.cpp - OOT Pass Plugin Entry Point ----*- C++ -*-===//
//
// Registers the Arkari obfuscation passes as an LLVM new-PM pass plugin.
//
//===----------------------------------------------------------------------===//

#include "llvm/Passes/PassBuilder.h"
#include "llvm/Transforms/Obfuscation/ObfuscationPassManager.h"

#include <cstdint>

using namespace llvm;

// Manually define PassPluginLibraryInfo to avoid the LLVM_ATTRIBUTE_WEAK
// declaration from PassPlugin.h which conflicts with dllexport.
extern "C" {
struct PassPluginLibraryInfo {
  uint32_t APIVersion;
  const char *PluginName;
  const char *PluginVersion;
  void (*RegisterPassBuilderCallbacks)(PassBuilder &);
  bool (*PreCodeGenCallback)(Module &, TargetMachine &, CodeGenFileType,
                             raw_pwrite_stream &OS);
};
}

// The plugin registration callback.
static void registerArkariPasses(PassBuilder &PB) {
  PB.registerOptimizerEarlyEPCallback(
      [](ModulePassManager &MPM, OptimizationLevel OL,
         ThinOrFullLTOPhase Phase) {
        MPM.addPass(ObfuscationPassManagerPass());
      });
}

// LLVM_PLUGIN_API_VERSION for LLVM 22
#define LLVM_PLUGIN_API_VERSION 2

extern "C" __declspec(dllexport) PassPluginLibraryInfo llvmGetPassPluginInfo() {
  return {LLVM_PLUGIN_API_VERSION, "Arkari", "1.7.0", registerArkariPasses,
          nullptr};
}


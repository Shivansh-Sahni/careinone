#!/usr/bin/env python3
"""Regenerate the checked-in Xcode project without third-party generators."""
from pathlib import Path
import hashlib
import json
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
def ident(text): return hashlib.sha1(text.encode()).hexdigest()[:24].upper()
def q(text): return json.dumps(str(text))
objects = {}
def add(name, body):
    key = ident(name); objects[key] = body; return key

main = ident('main'); products = ident('products'); project = ident('project')
app = ident('app'); tests = ident('uitests'); integration = ident('integration'); configs = ident('projectconfigs')
sources = []; resources = []; files = []
for path in sorted((ROOT/'CareContinuity').rglob('*')):
    if not path.is_file() or '/Core/' in str(path) or '/Assets.xcassets/' in str(path): continue
    rel = path.relative_to(ROOT).as_posix()
    if path.suffix not in ('.swift', '.xcprivacy', '.plist'): continue
    filetype = {'.swift':'sourcecode.swift','.xcprivacy':'text.xml','.plist':'text.plist.xml'}[path.suffix]
    ref = add('ref:'+rel, f'isa = PBXFileReference; lastKnownFileType = {filetype}; path = {q(rel)}; sourceTree = SOURCE_ROOT;')
    files.append(ref)
    if path.suffix == '.plist': continue
    build = add('build:'+rel, f'isa = PBXBuildFile; fileRef = {ref};')
    (sources if path.suffix == '.swift' else resources).append(build)
asset = add('asset', 'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = CareContinuity/Resources/Assets.xcassets; sourceTree = SOURCE_ROOT;')
files.append(asset); resources.append(add('assetbuild', f'isa = PBXBuildFile; fileRef = {asset};'))
app_product = add('appproduct', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = CareContinuity.app; sourceTree = BUILT_PRODUCTS_DIR;')
test_product = add('testproduct', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = CareContinuityUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
integration_product = add('integrationproduct', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = CareContinuityIntegrationTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
package = add('package', 'isa = XCLocalSwiftPackageReference; relativePath = .;')
dependency = add('coredependency', f'isa = XCSwiftPackageProductDependency; package = {package}; productName = CareCore;')
corebuild = add('corebuild', f'isa = PBXBuildFile; productRef = {dependency};')
def phase(name, isa, entries): return add(name, f'isa = {isa}; buildActionMask = 2147483647; files = ({",".join(entries)}); runOnlyForDeploymentPostprocessing = 0;')
source_phase = phase('sources','PBXSourcesBuildPhase',sources)
resource_phase = phase('resources','PBXResourcesBuildPhase',resources)
framework_phase = phase('frameworks','PBXFrameworksBuildPhase',[corebuild])
test_sources = []
for path in sorted((ROOT/'UITests').glob('*.swift')):
    rel = path.relative_to(ROOT).as_posix()
    ref = add('ref:'+rel, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(rel)}; sourceTree = SOURCE_ROOT;'); files.append(ref)
    test_sources.append(add('build:'+rel, f'isa = PBXBuildFile; fileRef = {ref};'))
test_phase = phase('testsources','PBXSourcesBuildPhase',test_sources)
test_frameworks = phase('testframeworks','PBXFrameworksBuildPhase',[])
integration_sources = []
for path in sorted((ROOT/'IntegrationTests').glob('*.swift')):
    rel = path.relative_to(ROOT).as_posix()
    ref = add('ref:'+rel, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(rel)}; sourceTree = SOURCE_ROOT;'); files.append(ref)
    integration_sources.append(add('build:'+rel, f'isa = PBXBuildFile; fileRef = {ref};'))
integration_phase = phase('integrationsources','PBXSourcesBuildPhase',integration_sources)
integration_core = add('integrationcore', f'isa = XCSwiftPackageProductDependency; package = {package}; productName = CareCore;')
integration_corebuild = add('integrationcorebuild', f'isa = PBXBuildFile; productRef = {integration_core};')
integration_frameworks = phase('integrationframeworks','PBXFrameworksBuildPhase',[integration_corebuild])
proxy = add('proxy', f'isa = PBXContainerItemProxy; containerPortal = {project}; proxyType = 1; remoteGlobalIDString = {app}; remoteInfo = CareContinuity;')
targetdep = add('testtargetdependency', f'isa = PBXTargetDependency; target = {app}; targetProxy = {proxy};')
def configuration_list(name, common):
    ids = []
    for config in ['Debug','Release']:
        settings = dict(common)
        if name == 'projectconfigs':
            settings.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if config == 'Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if config == 'Debug' else 'dwarf-with-dsym','ENABLE_TESTABILITY':'YES' if config == 'Debug' else 'NO'})
        if config == 'Debug':
            settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG $(inherited)'
            settings['ONLY_ACTIVE_ARCH'] = 'YES'
        body = '; '.join(f'{k} = {q(v)}' for k,v in settings.items()) + ';'
        ids.append(add(name+config, f'isa = XCBuildConfiguration; buildSettings = {{ {body} }}; name = {config};'))
    return add(name, f'isa = XCConfigurationList; buildConfigurations = ({",".join(ids)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
configuration_list('projectconfigs',{'IPHONEOS_DEPLOYMENT_TARGET':'18.0','SDKROOT':'iphoneos','SWIFT_VERSION':'6.0','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','ENABLE_USER_SCRIPT_SANDBOXING':'YES','SWIFT_STRICT_CONCURRENCY':'complete','CODE_SIGN_STYLE':'Automatic'})
app_configs = configuration_list('appconfigs', {'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'org.carecontinuity.app','INFOPLIST_FILE':'CareContinuity/Resources/Info.plist','TARGETED_DEVICE_FAMILY':'1,2','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME':'AccentColor','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SUPPORTS_MACCATALYST':'NO','ENABLE_PREVIEWS':'YES','CODE_SIGN_ENTITLEMENTS':'CareContinuity/Resources/CareContinuity.entitlements'})
test_configs = configuration_list('testconfigs', {'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'org.carecontinuity.uitests','GENERATE_INFOPLIST_FILE':'YES','TARGETED_DEVICE_FAMILY':'1,2','TEST_TARGET_NAME':'CareContinuity','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @loader_path/Frameworks'})
integration_configs = configuration_list('integrationconfigs', {'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'org.carecontinuity.integrationtests','GENERATE_INFOPLIST_FILE':'YES','TARGETED_DEVICE_FAMILY':'1,2','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/CareContinuity.app/CareContinuity','BUNDLE_LOADER':'$(TEST_HOST)','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @loader_path/Frameworks'})
add('app', f'isa = PBXNativeTarget; buildConfigurationList = {app_configs}; buildPhases = ({source_phase},{framework_phase},{resource_phase}); buildRules = (); dependencies = (); name = CareContinuity; packageProductDependencies = ({dependency}); productName = CareContinuity; productReference = {app_product}; productType = "com.apple.product-type.application";')
add('uitests', f'isa = PBXNativeTarget; buildConfigurationList = {test_configs}; buildPhases = ({test_phase},{test_frameworks}); buildRules = (); dependencies = ({targetdep}); name = CareContinuityUITests; productName = CareContinuityUITests; productReference = {test_product}; productType = "com.apple.product-type.bundle.ui-testing";')
add('integration', f'isa = PBXNativeTarget; buildConfigurationList = {integration_configs}; buildPhases = ({integration_phase},{integration_frameworks}); buildRules = (); dependencies = ({targetdep}); name = CareContinuityIntegrationTests; productName = CareContinuityIntegrationTests; productReference = {integration_product}; packageProductDependencies = ({integration_core}); productType = "com.apple.product-type.bundle.unit-test";')
add('products', f'isa = PBXGroup; children = ({app_product},{test_product},{integration_product}); name = Products; sourceTree = "<group>";')
add('main', f'isa = PBXGroup; children = ({",".join(files)},{products}); sourceTree = "<group>";')
add('project', f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastSwiftUpdateCheck = 2600; LastUpgradeCheck = 2600; TargetAttributes = {{ {app} = {{ CreatedOnToolsVersion = 26.0; }}; {tests} = {{ CreatedOnToolsVersion = 26.0; TestTargetID = {app}; }}; {integration} = {{ CreatedOnToolsVersion = 26.0; TestTargetID = {app}; }}; }}; }}; buildConfigurationList = {configs}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; packageReferences = ({package}); targets = ({app},{tests},{integration});')
project_dir = ROOT/'CareContinuity.xcodeproj'; project_dir.mkdir(exist_ok=True)
(project_dir/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 60; objects = {\n' + '\n'.join(f'{key} = {{ {body} }};' for key,body in objects.items()) + f'\n}}; rootObject = {project}; }}\n')
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app}" BuildableName="CareContinuity.app" BlueprintName="CareContinuity" ReferencedContainer="container:CareContinuity.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{tests}" BuildableName="CareContinuityUITests.xctest" BlueprintName="CareContinuityUITests" ReferencedContainer="container:CareContinuity.xcodeproj"/></TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app}" BuildableName="CareContinuity.app" BlueprintName="CareContinuity" ReferencedContainer="container:CareContinuity.xcodeproj"/></BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app}" BuildableName="CareContinuity.app" BlueprintName="CareContinuity" ReferencedContainer="container:CareContinuity.xcodeproj"/></BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>'''
integration_testable = f'<TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{integration}" BuildableName="CareContinuityIntegrationTests.xctest" BlueprintName="CareContinuityIntegrationTests" ReferencedContainer="container:CareContinuity.xcodeproj"/></TestableReference>'
scheme = scheme.replace('</Testables>',integration_testable+'</Testables>')
scheme_dir = project_dir/'xcshareddata/xcschemes'; scheme_dir.mkdir(parents=True,exist_ok=True); (scheme_dir/'CareContinuity.xcscheme').write_text(scheme)

# A simple code-drawn app icon, no downloaded or generated third-party artwork.
size=1024; rows=[]
for y in range(size):
    row=bytearray()
    for x in range(size):
        color=(13,110,102)
        # two interlocking rounded evidence loops
        def ring(cx,cy,rx,ry):
            d=((x-cx)/rx)**2+((y-cy)/ry)**2
            return 0.60 < d < 1.0
        if ring(420,430,180,245) or ring(600,600,180,245): color=(232,249,241)
        if (x-750)**2+(y-265)**2 < 48**2: color=(238,197,111)
        row.extend(color)
    rows.append(b'\0'+row)
def chunk(t,d): return struct.pack('!I',len(d))+t+d+struct.pack('!I',zlib.crc32(t+d)&0xffffffff)
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('!2I5B',size,size,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(rows),9))+chunk(b'IEND',b'')
assets=ROOT/'CareContinuity/Resources/Assets.xcassets'
(assets/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}}))
(assets/'AppIcon.appiconset/AppIcon.png').write_bytes(png)
(assets/'AppIcon.appiconset/Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}],'info':{'author':'xcode','version':1}}))
(assets/'AccentColor.colorset/Contents.json').write_text(json.dumps({'colors':[{'idiom':'universal','color':{'color-space':'srgb','components':{'red':'0.051','green':'0.431','blue':'0.400','alpha':'1.000'}}}],'info':{'author':'xcode','version':1}}))
print('Generated CareContinuity.xcodeproj and app assets.')

# Shell-to-Python Migration Plan

**Status**: In Progress  
**Target Release**: v0.5.0  
**Timeline**: Gradual deprecation with Python-first approach

---

## Strategic Direction

Move from bash-heavy orchestration logic to Python-first CLI, keeping shell scripts as thin compatibility wrappers during transition period.

### Goals

1. **Testability**: Python code is easier to unit test than shell
2. **Maintainability**: Orchestration logic centralized in Python classes
3. **Reusability**: Python classes can be imported and used by other projects
4. **Performance**: Avoid subprocess overhead of chained shell scripts
5. **Cross-Platform**: Python code works on macOS/Linux without shell compatibility issues

---

## Current Shell Architecture (Pre-Refactoring)

```
setup.sh (dispatcher)
  ├── ubuntu/setup.sh (orchestrates Ubuntu build)
  │   ├── lib/_00-common-functions.sh (config/validation)
  │   ├── lib/_01-install-deps.sh (dependency check)
  │   ├── lib/_02-generate-password-hash.sh (password gen)
  │   ├── lib/_03-prepare-workdir.sh (path validation, WORK/ROOT setup)
  │   ├── lib/_04-render-autoinstall.py (template rendering)
  │   ├── lib/_06-rebuild-md5.py (ISO patching)
  │   └── lib/_07-build-iso.sh (ISO build)
  │
  ├── debian/setup.sh
  │   ├── Similar workflow to Ubuntu
  │   └── lib/_05-patch-grub-debian.py (GRUB preseed injection)
  │
  └── haos/setup.sh
      ├── lib/_09-download-haos-image.sh (image download)
      └── lib/_10-finalize-haos-image.sh (image preparation)

build_and_flash.sh (dispatcher)
  ├── ubuntu/build_and_flash.sh
  ├── debian/build_and_flash.sh
  └── haos/build_and_flash.sh
      ├── lib/_08-flash-image.sh (USB flash with safety checks)
      ├── lib/_991-start-status-server.sh (status callback server)
      └── lib/_99-generate-handoff.py (handoff JSON generation)
```

---

## Target Python Architecture (Post-Refactoring)

```
python -m assembler <command>
  │
  ├── build --variant [ubuntu|debian|haos] [OPTIONS]
  │   └── BuildOrchestrator (orchestrates full build)
  │       ├── ConfigManager (loads/validates config)
  │       ├── DependencyChecker (apt/brew packages)
  │       ├── PathValidator (WORK/ROOT validation)
  │       ├── TemplateRenderer (renders autoinstall/preseed/user-data)
  │       ├── ImageBuilder (ISO patching/build)
  │       └── HandoffGenerator (creates JSON artifact)
  │
  ├── flash --image ISO_PATH --disk /dev/diskN [--dry-run]
  │   └── FlashOperation (USB flash with safety)
  │       ├── DiskValidator (rejects system disks)
  │       ├── FlashPlanner (previews operation)
  │       └── FlashExecutor (writes to disk)
  │
  ├── status-server --port 8081
  │   └── StatusServer (receives installer callbacks)
  │
  ├── validate-config --config config.env
  │   └── ConfigValidator (syntax, required keys, hashes)
  │
  └── generate-handoff --config config.env --output-dir .coordination/
      └── HandoffGenerator (creates JSON artifact)
```

---

## Migration Phases

### Phase 1: Create Python Orchestration Classes ✅ (CURRENT)

- [x] Design BuildOrchestrator class
- [x] Design FlashOperation class  
- [x] Design StatusServer integration
- [x] Implement WorkflowContext (config + paths)
- [ ] Add comprehensive tests for each class
- [ ] Document Python API

### Phase 2: Expand CLI to Use New Classes

- [ ] Add `build` subcommand to cli.py
- [ ] Add `flash` subcommand to cli.py
- [ ] Add `validate-config` subcommand
- [ ] Ensure all commands are tested
- [ ] Create console script entry point: `assembler` (via pyproject.toml)

### Phase 3: Shell Wrapper Compatibility Layer

- [ ] Keep setup.sh as dispatcher, update to call Python CLI
- [ ] Keep build_and_flash.sh as wrapper, call Python CLI
- [ ] Add deprecation warnings to shell scripts
- [ ] Maintain backward compatibility through v0.4 and v0.5

### Phase 4: Deprecation & Cleanup (v0.6+)

- [ ] Remove shell scripts marked for deletion
- [ ] Make Python CLI the official interface
- [ ] Update documentation to point to Python CLI
- [ ] Archive old shell scripts as reference

### Phase 5: Advanced Features (Optional)

- [ ] HAOS/Home Assistant Supervisor API bridge
- [ ] Network configuration abstraction
- [ ] Status callback aggregation
- [ ] Rollback/resume capabilities

---

## File-by-File Migration Status

### KEEP (Shell Compatibility Wrappers)

```
setup.sh                                  → Wrapper to call python -m assembler build
build_and_flash.sh                        → Wrapper to call python -m assembler flash
ubuntu/setup.sh                           → Wrapper, deprecated
debian/setup.sh                           → Wrapper, deprecated
haos/setup.sh                             → Wrapper, deprecated
ubuntu/build_and_flash.sh                 → Wrapper, deprecated
debian/build_and_flash.sh                 → Wrapper, deprecated
haos/build_and_flash.sh                   → Wrapper, deprecated
```

### MOVE to Python (Implement as Classes)

```
lib/_00-common-functions.sh               → assembler.config.ConfigManager
lib/_01-install-deps.sh                   → assembler.build.DependencyChecker
lib/_02-generate-password-hash.sh         → assembler.password (keep, already tested)
lib/_03-prepare-workdir.sh                → assembler.build.PathValidator
lib/_08-flash-image.sh                    → assembler.flash.FlashOperation
lib/_991-start-status-server.sh           → assembler.server.StatusServer
```

### KEEP (Already Python)

```
lib/_04-render-autoinstall.py             → assembler.build.AutoinstallRenderer
lib/_04-render-template.py                → assembler.template.TemplateRenderer (extend)
lib/_05-patch-grub-debian.py              → assembler.build.GrubPreseedPatcher
lib/_05-patch-grub.py                     → assembler.build.GrubBootPatcher
lib/_06-rebuild-md5.py                    → assembler.build.ISOHasher
lib/_07-build-iso.sh                      → Call xorriso via assembler.build.ISOBuilder
lib/_09-download-haos-image.sh            → assembler.build.HAOSImageDownloader
lib/_10-finalize-haos-image.sh            → assembler.build.HAOSImagePreparer
lib/_99-generate-handoff.py               → assembler.build.HandoffGenerator (keep tests)
```

---

## Python Class Design (Proposed)

### Core Classes

#### `WorkflowContext`

Manages configuration, paths, and environment for a build/flash operation.

```python
class WorkflowContext:
    def __init__(self, config_path: Path, variant: str = "ubuntu"):
        self.config = ConfigManager(config_path)
        self.variant = variant
        self.work_path = self.config.get("WORK_DIR")
        self.root_path = self.config.get("ROOT_PATH")
        
    def validate(self) -> bool:
        """Validate WORK and ROOT paths."""
    
    def get_iso_path(self) -> Path:
        """Get expected ISO output path."""
```

#### `BuildOrchestrator`

Orchestrates the full build workflow.

```python
class BuildOrchestrator:
    def __init__(self, context: WorkflowContext):
        self.context = context
        self.deps = DependencyChecker()
        self.renderer = TemplateRenderer()
        self.builder = ISOBuilder()
        
    def build(self) -> Path:
        """Execute full build workflow."""
        self.deps.check()
        self.context.validate()
        self._render_templates()
        self._patch_bootloader()
        iso_path = self._build_iso()
        return iso_path
```

#### `FlashOperation`

Handles USB flash with safety checks.

```python
class FlashOperation:
    def __init__(self, image_path: Path, target_disk: str):
        self.image = image_path
        self.target = target_disk
        self.validator = DiskValidator()
        
    def plan(self) -> FlashPlan:
        """Show what will happen (dry-run)."""
        self.validator.check_safety(self.target)
        return FlashPlan(self.image, self.target)
    
    def execute(self, confirmation: str = "") -> bool:
        """Execute flash if confirmation phrase matches."""
        if confirmation != "flash USB":
            raise ValueError("Invalid confirmation phrase")
        # Perform flash
```

#### `StatusServer`

Receives installer callbacks.

```python
class StatusServer:
    def __init__(self, host: str = "0.0.0.0", port: int = 8081):
        self.host = host
        self.port = port
    
    def start(self) -> None:
        """Start listening for callbacks."""
    
    def get_callbacks(self) -> List[Dict]:
        """Get received callbacks."""
```

---

## Testing Strategy

### Python Classes (New)

- Unit tests for each orchestration class
- Integration tests for full workflows
- YAML validation tests for cloud-init templates
- Disk safety validation tests (mocked)

### Shell Scripts (Existing)

- Keep existing bash tests passing during transition
- Bash tests become compatibility tests
- Eventually deprecate as Python tests take over

### Example: YAML Validation Test (Debian Cloud-Init)

```python
def test_debian_cloud_init_yaml_valid():
    """Verify cloud-init user-data is valid YAML."""
    context = WorkflowContext(Path("config.env"))
    renderer = TemplateRenderer()
    user_data = renderer.render("debian_user_data", context.config)
    
    # Should not raise YAML validation error
    yaml.safe_load(user_data)
    
    # Verify no unquoted Content-Type in runcmd
    assert "Content-Type:" not in user_data.split("runcmd:")[1]
```

---

## Implementation Timeline

**Week 1**:

- [ ] Design and implement WorkflowContext
- [ ] Design and implement BuildOrchestrator
- [ ] Add tests for orchestration classes
- [ ] Document new Python API

**Week 2**:

- [ ] Design and implement FlashOperation
- [ ] Design and implement StatusServer bridge
- [ ] Add tests for flash and status operations
- [ ] Create YAML validation tests

**Week 3**:

- [ ] Expand cli.py with new subcommands
- [ ] Create console script entry point
- [ ] Update shell scripts to be wrappers
- [ ] Add deprecation warnings

**Week 4**:

- [ ] Comprehensive integration testing
- [ ] Update documentation
- [ ] Prepare v0.5.0 release

**Post-Release**:

- [ ] Gather feedback from pilot tests
- [ ] Plan shell script removal (v0.6)
- [ ] Implement advanced features as requested

---

## Benefits After Completion

✅ **Cleaner CI/CD**: Use Python CLI directly, no shell script complexity  
✅ **Better Testing**: Python code coverage tools, easier mocking  
✅ **Faster Execution**: No subprocess overhead  
✅ **Cross-Platform**: Better support for Windows/WSL (future)  
✅ **Reusable**: Other projects can import assembler classes  
✅ **IDE Support**: Full autocomplete, type hints, refactoring tools  

---

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Shell scripts still in use during transition | Breaking changes | Keep wrappers, extensive backward compat testing |
| Python version compatibility | Env issues | Pin Python 3.9+, test in CI |
| CLI interface change friction | User confusion | Gradual deprecation, documentation, migration guide |
| Performance regression | Build times increase | Benchmark before/after, optimize as needed |

---

## Success Criteria

- [x] Pilot results documented (Debian, HAOS)
- [ ] All Python orchestration classes implemented
- [ ] 100% test coverage for new Python code
- [ ] All existing tests still passing
- [ ] Backward-compatible shell wrappers functional
- [ ] Documentation updated with examples
- [ ] v0.5.0 release with Python-first CLI

const fs = require('fs');
let content = fs.readFileSync('lib/onboarding_screen.dart', 'utf8');

const marker = '  Widget _s0BasicInfo() {';
const start = content.indexOf(marker);
if (start < 0) { console.log('NOT FOUND'); process.exit(1); }

// Find the closing brace by tracking brace depth
let braceDepth = 0;
let i = start;
let inBody = false;
let end = -1;
for (; i < content.length; i++) {
  if (content[i] === '{') { braceDepth++; inBody = true; }
  else if (content[i] === '}') {
    braceDepth--;
    if (inBody && braceDepth === 0) { end = i + 1; break; }
  }
}
console.log('start:', start, 'end:', end);
console.log('Old snippet:', JSON.stringify(content.slice(start, start+200)));

const newBody = [
  "  Widget _s0BasicInfo() {",
  "    return SingleChildScrollView(",
  "      padding: const EdgeInsets.all(24),",
  "      child: Column(",
  "        children: [",
  "          _header(\"Let's get to know you\", \"Add a photo and your basic details\"),",
  "          GestureDetector(",
  "            onTap: _handlePhotoUpload,",
  "            child: Container(",
  "              width: 120, height: 120,",
  "              decoration: BoxDecoration(",
  "                shape: BoxShape.circle, color: _card,",
  "                border: Border.all(color: _photoUrl != null ? _cyan : _gb, width: 2),",
  "                boxShadow: _photoUrl != null ? [BoxShadow(color: _cyan.withValues(alpha: 0.25), blurRadius: 16)] : null,",
  "              ),",
  "              child: _photoUrl != null",
  "                  ? ClipOval(child: Image.network(_photoUrl!, fit: BoxFit.cover))",
  "                  : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [",
  "                      Icon(Icons.camera_alt, color: _muted, size: 30),",
  "                      SizedBox(height: 8),",
  "                      Text('Add Photo', style: TextStyle(color: _cyan, fontSize: 12)),",
  "                    ]),",
  "            ),",
  "          ),",
  "          const SizedBox(height: 30),",
  "          _inputField('First Name', _displayNameCtrl, Icons.person),",
  "          const SizedBox(height: 16),",
  "          GestureDetector(",
  "            onTap: () => setState(() => _dobPickerExpanded = !_dobPickerExpanded),",
  "            child: AnimatedContainer(",
  "              duration: const Duration(milliseconds: 200),",
  "              decoration: BoxDecoration(",
  "                color: _card,",
  "                borderRadius: BorderRadius.circular(16),",
  "                border: Border.all(",
  "                  color: _dobPickerExpanded ? _cyan : (_dobCtrl.text.isNotEmpty ? _cyan.withValues(alpha: 0.5) : _gb),",
  "                  width: _dobPickerExpanded ? 1.5 : 1,",
  "                ),",
  "              ),",
  "              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),",
  "              child: Row(",
  "                children: [",
  "                  Icon(Icons.cake_outlined, color: _dobCtrl.text.isNotEmpty ? _cyan : _muted, size: 22),",
  "                  const SizedBox(width: 14),",
  "                  Expanded(",
  "                    child: _dobCtrl.text.isNotEmpty",
  "                        ? Column(",
  "                            crossAxisAlignment: CrossAxisAlignment.start,",
  "                            children: [",
  "                              Text('Date of Birth', style: GoogleFonts.inter(color: _muted, fontSize: 11)),",
  "                              const SizedBox(height: 2),",
  "                              Text(",
  "                                (() {",
  "                                  try {",
  "                                    final d = DateTime.parse(_dobCtrl.text);",
  "                                    return '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';",
  "                                  } catch (e) { return _dobCtrl.text; }",
  "                                })(),",
  "                                style: GoogleFonts.inter(color: _txt, fontSize: 16, fontWeight: FontWeight.w600),",
  "                              ),",
  "                            ],",
  "                          )",
  "                        : Text('Tap to select Date of Birth', style: GoogleFonts.inter(color: _muted, fontSize: 15)),",
  "                  ),",
  "                  Icon(",
  "                    _dobPickerExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,",
  "                    color: _muted, size: 20,",
  "                  ),",
  "                ],",
  "              ),",
  "            ),",
  "          ),",
  "          if (_dobPickerExpanded) _buildDobPicker(),",
  "          const SizedBox(height: 16),",
  "          _inputField('Bio \u2014 tell people about yourself', _bioCtrl, Icons.edit_note),",
  "        ],",
  "      ),",
  "    );",
  "  }"
].join('\n');

content = content.slice(0, start) + newBody + content.slice(end);
fs.writeFileSync('lib/onboarding_screen.dart', content, 'utf8');
console.log('DONE - written successfully');

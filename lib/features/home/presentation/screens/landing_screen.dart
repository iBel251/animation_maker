import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:animation_maker/features/canvas/domain/entities/canvas_document_summary.dart';
import 'package:animation_maker/features/canvas/presentation/providers/repository_providers.dart';
import 'package:animation_maker/features/canvas/presentation/screens/canvas_screen.dart';
import 'package:animation_maker/features/home/presentation/widgets/new_project_dialog.dart';

enum LandingSection { projects, assets }

enum LandingNav { home, search, learn }

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  LandingSection _section = LandingSection.projects;
  LandingNav _nav = LandingNav.home;
  late Future<List<CanvasDocumentSummary>> _projectsFuture;

  final List<_LandingAsset> _assets = const [
    _LandingAsset(name: 'City Pack', type: 'PNG', accent: Color(0xFF22D3EE)),
    _LandingAsset(name: 'SFX Bumps', type: 'WAV', accent: Color(0xFFA78BFA)),
    _LandingAsset(name: 'Ink Brushes', type: 'BRUSH', accent: Color(0xFFF97316)),
    _LandingAsset(name: 'Voice Set', type: 'MP3', accent: Color(0xFF34D399)),
    _LandingAsset(name: 'UI Icons', type: 'SVG', accent: Color(0xFF60A5FA)),
    _LandingAsset(name: 'Paper Textures', type: 'JPG', accent: Color(0xFFFBBF24)),
  ];

  @override
  void initState() {
    super.initState();
    _projectsFuture = _fetchProjects();
  }

  Future<List<CanvasDocumentSummary>> _fetchProjects() {
    final repo = ref.read(canvasRepositoryProvider);
    return repo.listDocuments();
  }

  void _refreshProjects() {
    setState(() {
      _projectsFuture = _fetchProjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF4F0E8);
    const panel = Color(0xFFFFFFFF);
    const accent = Color(0xFF1D4ED8);
    const muted = Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: background,
      drawer: const _LandingDrawer(),
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: _LogoBadge(),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _nav == LandingNav.home
            ? _buildHomeBody(
                context,
                panel: panel,
                accent: accent,
                muted: muted,
              )
            : _buildAuxBody(
                context,
                panel: panel,
                accent: accent,
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        onPressed: () => _showNewProjectDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _LandingBottomNav(
        current: _nav,
        onSelect: (value) => setState(() => _nav = value),
      ),
    );
  }

  Widget _buildHomeBody(
    BuildContext context, {
    required Color panel,
    required Color accent,
    required Color muted,
  }) {
    return ListView(
      key: const ValueKey('home'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        _HeroCard(accent: accent),
        const SizedBox(height: 18),
        _SectionHeader(
          title: 'Library',
          subtitle: 'Jump back into the work you were shaping.',
        ),
        const SizedBox(height: 12),
        _SegmentRow(
          section: _section,
          onChanged: (value) => setState(() => _section = value),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            return _section == LandingSection.projects
                ? FutureBuilder<List<CanvasDocumentSummary>>(
                    future: _projectsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final projects = snapshot.data ?? const [];
                      if (projects.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: panel,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE7E5E4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'No projects yet',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Tap New Project to start your first animation.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return _ProjectsGrid(
                        projects: projects,
                        maxWidth: constraints.maxWidth,
                        panel: panel,
                        muted: muted,
                        onOpen: (project) => _openProject(project.id),
                      );
                    },
                  )
                : _AssetsGrid(
                    assets: _assets,
                    maxWidth: constraints.maxWidth,
                    panel: panel,
                    muted: muted,
                  );
          },
        ),
        const SizedBox(height: 20),
        _SectionHeader(
          title: 'Quick Actions',
          subtitle: 'Shortcuts to keep things moving.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: const [
            _QuickActionCard(
              icon: Icons.upload_file,
              title: 'Import assets',
              subtitle: 'Bring in audio or video.',
            ),
            _QuickActionCard(
              icon: Icons.layers_outlined,
              title: 'Layer presets',
              subtitle: 'Start with onion skin.',
            ),
            _QuickActionCard(
              icon: Icons.auto_fix_high,
              title: 'Auto cleanup',
              subtitle: 'Trim empty frames.',
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showNewProjectDialog(BuildContext context) async {
    final projectId = await showDialog<String>(
      context: context,
      builder: (context) => const NewProjectDialog(),
    );
    if (!mounted || projectId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CanvasScreen(documentId: projectId),
      ),
    );
    if (!mounted) return;
    _refreshProjects();
  }

  Future<void> _openProject(String projectId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CanvasScreen(documentId: projectId),
      ),
    );
    if (!mounted) return;
    _refreshProjects();
  }

  Widget _buildAuxBody(
    BuildContext context, {
    required Color panel,
    required Color accent,
  }) {
    if (_nav == LandingNav.search) {
      return ListView(
        key: const ValueKey('search'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          const _SectionHeader(
            title: 'Search',
            subtitle: 'Find projects, assets, and notes.',
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by name or tag',
              filled: true,
              fillColor: panel,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _SectionHeader(
            title: 'Recent searches',
            subtitle: 'Concepts, color tests, sprites.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _Pill(label: 'Walk cycles'),
              _Pill(label: 'Ink brush'),
              _Pill(label: 'Chase scene'),
              _Pill(label: 'Voice takes'),
            ],
          ),
        ],
      );
    }

    return ListView(
      key: const ValueKey('learn'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        const _SectionHeader(
          title: 'Learn',
          subtitle: 'Guides built around your workflow.',
        ),
        const SizedBox(height: 12),
        _LearnCard(
          title: 'Onion skin basics',
          subtitle: 'Keep timing tight while you draw.',
          duration: '6 min',
          accent: accent,
        ),
        const SizedBox(height: 12),
        _LearnCard(
          title: 'Clean line workflow',
          subtitle: 'Turn roughs into crisp strokes.',
          duration: '9 min',
          accent: accent,
        ),
        const SizedBox(height: 12),
        _LearnCard(
          title: 'Audio sync',
          subtitle: 'Match mouth shapes to voice.',
          duration: '8 min',
          accent: accent,
        ),
      ],
    );
  }
}

class _LandingBottomNav extends StatelessWidget {
  const _LandingBottomNav({
    required this.current,
    required this.onSelect,
  });

  final LandingNav current;
  final ValueChanged<LandingNav> onSelect;

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF4F0E8);
    const accent = Color(0xFF1D4ED8);
    const muted = Color(0xFF6B7280);

    return BottomAppBar(
      color: background,
      elevation: 0,
      notchMargin: 8,
      shape: const CircularNotchedRectangle(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  _NavButton(
                    icon: Icons.search,
                    label: 'Search',
                    isActive: current == LandingNav.search,
                    accent: accent,
                    muted: muted,
                    onTap: () => onSelect(LandingNav.search),
                  ),
                  const SizedBox(width: 8),
                  _NavButton(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    isActive: current == LandingNav.home,
                    accent: accent,
                    muted: muted,
                    onTap: () => onSelect(LandingNav.home),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 72),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _NavButton(
                    icon: Icons.school_rounded,
                    label: 'Learn',
                    isActive: current == LandingNav.learn,
                    accent: accent,
                    muted: muted,
                    onTap: () => onSelect(LandingNav.learn),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.accent,
    required this.muted,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final Color accent;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? accent : muted;
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(height: 0),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                height: 1,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingDrawer extends StatelessWidget {
  const _LandingDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF1D4ED8),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Animation Maker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Georgia',
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Themes'),
            onTap: () => Navigator.of(context).pop(),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('Local storage'),
            onTap: () => Navigator.of(context).pop(),
          ),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('Cloud sync'),
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E1D7)),
      ),
      child: Row(
        children: const [
          Icon(Icons.motion_photos_auto, size: 18, color: Color(0xFF1D4ED8)),
          SizedBox(width: 6),
          Text(
            'Animatrix',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              fontFamily: 'Georgia',
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFDE68A),
            Color(0xFFFCA5A5),
            Color(0xFF93C5FD),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 8,
            top: 6,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.45),
              ),
            ),
          ),
          Positioned(
            right: 48,
            bottom: 4,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.25),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sketch, animate, ship.',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Georgia',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your last frames are saved automatically. Jump in and keep the motion going.',
                style: TextStyle(fontSize: 14, height: 1.35),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Auto-save active',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.circle, size: 8, color: accent),
                  const SizedBox(width: 6),
                  const Text('Sync ready'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFamily: 'Georgia',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}

class _SegmentRow extends StatelessWidget {
  const _SegmentRow({required this.section, required this.onChanged});

  final LandingSection section;
  final ValueChanged<LandingSection> onChanged;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF1D4ED8);
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Projects'),
                  selected: section == LandingSection.projects,
                  onSelected: (_) => onChanged(LandingSection.projects),
                  selectedColor: accent.withOpacity(0.15),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: section == LandingSection.projects
                        ? accent
                        : Colors.black87,
                  ),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Assets'),
                  selected: section == LandingSection.assets,
                  onSelected: (_) => onChanged(LandingSection.assets),
                  selectedColor: accent.withOpacity(0.15),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color:
                        section == LandingSection.assets ? accent : Colors.black87,
                  ),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.filter_list),
          label: const Text('Filter'),
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
      ],
    );
  }
}

class _ProjectsGrid extends StatelessWidget {
  const _ProjectsGrid({
    required this.projects,
    required this.maxWidth,
    required this.panel,
    required this.muted,
    required this.onOpen,
  });

  final List<CanvasDocumentSummary> projects;
  final double maxWidth;
  final Color panel;
  final Color muted;
  final ValueChanged<CanvasDocumentSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final columns = maxWidth >= 980
        ? 3
        : maxWidth >= 640
            ? 2
            : 1;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: projects.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: columns == 1 ? 2.2 : 1.6,
      ),
      itemBuilder: (context, index) {
        final project = projects[index];
        final accent = _accentForId(project.id);
        final updatedLabel = _formatUpdatedAt(project.updatedAt);
        return Material(
          color: panel,
          elevation: 0,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onOpen(project),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE7E5E4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.movie_creation_outlined, color: accent),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    project.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Canvas project',
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: muted),
                      const SizedBox(width: 6),
                      Text(
                        'Edited $updatedLabel',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Color _accentForId(String id) {
  const accents = [
    Color(0xFFFB7185),
    Color(0xFF38BDF8),
    Color(0xFFF59E0B),
    Color(0xFF34D399),
    Color(0xFFA78BFA),
    Color(0xFF60A5FA),
  ];
  var hash = 0;
  for (final unit in id.codeUnits) {
    hash = (hash + unit) & 0x7FFFFFFF;
  }
  return accents[hash % accents.length];
}

String _formatUpdatedAt(DateTime value) {
  final now = DateTime.now();
  final diff = now.difference(value);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${value.month}/${value.day}/${value.year}';
}

class _AssetsGrid extends StatelessWidget {
  const _AssetsGrid({
    required this.assets,
    required this.maxWidth,
    required this.panel,
    required this.muted,
  });

  final List<_LandingAsset> assets;
  final double maxWidth;
  final Color panel;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final columns = maxWidth >= 980
        ? 4
        : maxWidth >= 720
            ? 3
            : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: assets.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final asset = assets[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7E5E4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: asset.accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.insert_drive_file, color: asset.accent),
              ),
              const Spacer(),
              Text(
                asset.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                asset.type,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1D4ED8)),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _LearnCard extends StatelessWidget {
  const _LearnCard({
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final String duration;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.play_arrow, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              duration,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _LandingAsset {
  const _LandingAsset({
    required this.name,
    required this.type,
    required this.accent,
  });

  final String name;
  final String type;
  final Color accent;
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../logic/timetable_provider.dart';
import '../data/models.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Start on the current day (Monday = 0, so weekday - 1)
    _tabController = TabController(length: 7, vsync: this, initialIndex: DateTime.now().weekday - 1);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable'),
        elevation: 0,
        actions: [
          // AI Import Button
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            tooltip: 'AI Auto-Import',
            onPressed: () => _showAiHelper(context, provider),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Mon'),
            Tab(text: 'Tue'),
            Tab(text: 'Wed'),
            Tab(text: 'Thu'),
            Tab(text: 'Fri'),
            Tab(text: 'Sat'),
            Tab(text: 'Sun'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(7, (index) {
          final day = index + 1; // 1 = Mon, 7 = Sun
          return _DayScheduleView(day: day, provider: provider);
        }),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showManualAdd(context, provider),
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- DIALOGS ---

  void _showAiHelper(BuildContext context, TimetableProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("AI Auto-Import"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "1. Copy Prompt.\n2. Paste in ChatGPT with your timetable image.\n3. Paste the JSON result here.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(const ClipboardData(
                    text: "Convert this timetable image to a JSON array. Fields: title, location, day (e.g. Monday), startTime (HH:MM), endTime (HH:MM), type (class/exam/event)."));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Prompt copied to clipboard!")));
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text("Copy Prompt"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Paste JSON here"),
              maxLines: 5,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          FilledButton(
            onPressed: () {
              final res = provider.importJson(controller.text);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res)));
            },
            child: const Text("Import"),
          )
        ],
      ),
    );
  }

  void _showManualAdd(BuildContext context, TimetableProvider provider) {
    // Simplified Manual Add for quick testing
    // In a full app, use time pickers and dropdowns
    final titleCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("Add Class"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Subject")),
          TextField(controller: locCtrl, decoration: const InputDecoration(labelText: "Location")),
          const SizedBox(height: 10),
          const Text("Defaulting to current day & time for demo.", style: TextStyle(fontSize: 10, color: Colors.grey))
        ]),
        actions: [
          FilledButton(onPressed: (){
            provider.addItem(ScheduleItem(
              id: DateTime.now().toString(),
              title: titleCtrl.text,
              location: locCtrl.text,
              weekday: DateTime.now().weekday,
              startHour: TimeOfDay.now().hour, startMinute: TimeOfDay.now().minute,
              endHour: TimeOfDay.now().hour + 1, endMinute: TimeOfDay.now().minute,
              type: 'class'
            ));
            Navigator.pop(ctx);
          }, child: const Text("Save"))
        ],
      )
    );
  }
}

class _DayScheduleView extends StatelessWidget {
  final int day;
  final TimetableProvider provider;

  const _DayScheduleView({required this.day, required this.provider});

  @override
  Widget build(BuildContext context) {
    final bool isToday = day == DateTime.now().weekday;
    final items = provider.getItemsForDay(day);
    
    // Dashboard Data (Only calculated if today)
    final status = isToday ? provider.getNowAndNext() : null;
    final isLunch = isToday ? provider.isLunchGap() : false;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- DASHBOARD SECTION (Only show on Today's Tab) ---
        if (isToday) ...[
          // 1. Lunch Alert
          if (isLunch)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.restaurant, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("Lunch Break!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        Text("12 PM - 3 PM Gap detected.", style: TextStyle(color: Colors.black87, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // 2. Now & Next Cards
          Row(
            children: [
              Expanded(child: _StatusCard(title: 'NOW', item: status?['current'], isActive: true)),
              const SizedBox(width: 12),
              Expanded(child: _StatusCard(title: 'NEXT', item: status?['next'], isActive: false)),
            ],
          ),
          
          const SizedBox(height: 24),
          Text(
            "Today's Schedule", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)
          ),
          const SizedBox(height: 10),
        ],

        // --- TIMETABLE LIST SECTION ---
        if (items.isEmpty) 
           Padding(
             padding: const EdgeInsets.only(top: 40),
             child: Center(
               child: Column(
                 children: [
                   Icon(Icons.event_busy, size: 48, color: Colors.grey.shade300),
                   const SizedBox(height: 10),
                   const Text("No classes scheduled.", style: TextStyle(color: Colors.grey)),
                 ],
               ),
             ),
           )
        else
          ...items.map((item) => _ClassTile(item: item, provider: provider)),
          
        // Extra padding at bottom for FAB
        const SizedBox(height: 80), 
      ],
    );
  }
}

// --- WIDGETS ---

class _StatusCard extends StatelessWidget {
  final String title;
  final ScheduleItem? item;
  final bool isActive;

  const _StatusCard({required this.title, required this.item, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final bgColor = isActive ? Theme.of(context).primaryColor : Colors.white;
    final txtColor = isActive ? Colors.white : Colors.black87;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isActive ? [BoxShadow(color: bgColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
        border: isActive ? null : Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: txtColor.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          if (item == null)
            Text(isActive ? "Free Time" : "Nothing later", style: TextStyle(color: txtColor, fontSize: 16, fontWeight: FontWeight.w600))
          else ...[
            Text(
              item!.title, 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: txtColor, fontSize: 16, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 4),
            Text(
              "${item!.location} • ${_fmt(item!.startHour, item!.startMinute)}", 
              style: TextStyle(color: txtColor.withOpacity(0.9), fontSize: 12)
            ),
          ]
        ],
      ),
    );
  }
  
  String _fmt(int h, int m) => "${h == 0 ? 12 : (h > 12 ? h - 12 : h)}:${m.toString().padLeft(2, '0')}";
}

class _ClassTile extends StatelessWidget {
  final ScheduleItem item;
  final TimetableProvider provider;

  const _ClassTile({required this.item, required this.provider});

  @override
  Widget build(BuildContext context) {
    final bool isExam = item.type == 'exam';
    // Generate color deterministically based on title length if it's a class
    final Color stripeColor = isExam 
        ? Colors.red 
        : Colors.primaries[item.title.length % Colors.primaries.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isExam ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isExam ? Border.all(color: Colors.red.shade200) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Colored Stripe
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: stripeColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.title, 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 16,
                            color: isExam ? Colors.red.shade900 : Colors.black87
                          )
                        ),
                        if (isExam) 
                          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${item.location} • ${_fmt(item.startHour, item.startMinute)} - ${_fmt(item.endHour, item.endMinute)}",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            // Attendance / Delete Buttons
            // Only show Attendance check if the class has passed or started
            if (_hasStarted(item))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.check_circle, color: item.attended == true ? Colors.green : Colors.grey.shade300),
                    onPressed: () => provider.toggleAttendance(item, true),
                    tooltip: "Attended",
                  ),
                  IconButton(
                    icon: Icon(Icons.cancel, color: item.attended == false ? Colors.red : Colors.grey.shade300),
                    onPressed: () => provider.toggleAttendance(item, false),
                    tooltip: "Missed",
                  ),
                ],
              )
            else
               IconButton(
                 icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                 onPressed: () => provider.deleteItem(item),
               ),
             const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  bool _hasStarted(ScheduleItem item) {
    // Check if current time > start time (on Today) OR if day is in past
    final now = DateTime.now();
    if (item.weekday < now.weekday) return true;
    if (item.weekday > now.weekday) return false;
    // Same day logic
    final nowMin = now.hour * 60 + now.minute;
    final startMin = item.startHour * 60 + item.startMinute;
    return nowMin >= startMin;
  }

  String _fmt(int h, int m) {
    final suffix = h >= 12 ? "PM" : "AM";
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return "$hour12:${m.toString().padLeft(2, '0')} $suffix";
  }
}
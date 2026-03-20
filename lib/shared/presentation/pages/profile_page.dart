import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../features/users/datasources/models/user_model.dart';
import '../../features/users/datasources/providers/user_provider.dart';
import '../../utilities/cloudinary_service.dart';
import '../widgets/profile/change_password_dialog.dart';
import '../widgets/profile/delete_account_dialog.dart';
import '../widgets/profile/profile_header.dart';
import '../widgets/profile/profile_info_row.dart';
import '../widgets/profile/profile_section_card.dart';
import '../widgets/profile/profile_status_row.dart';

class ProfilePageController extends ChangeNotifier {
  bool _isEditingProfile = false;
  bool _isSavingProfile = false;
  VoidCallback? _enterEditMode;
  VoidCallback? _cancelEditMode;
  Future<void> Function()? _saveProfileChanges;

  bool get isEditingProfile => _isEditingProfile;
  bool get isSavingProfile => _isSavingProfile;

  void bind({
    required bool isEditingProfile,
    required bool isSavingProfile,
    required VoidCallback enterEditMode,
    required VoidCallback cancelEditMode,
    required Future<void> Function() saveProfileChanges,
  }) {
    _isEditingProfile = isEditingProfile;
    _isSavingProfile = isSavingProfile;
    _enterEditMode = enterEditMode;
    _cancelEditMode = cancelEditMode;
    _saveProfileChanges = saveProfileChanges;
    notifyListeners();
  }

  void unbind() {
    _enterEditMode = null;
    _cancelEditMode = null;
    _saveProfileChanges = null;
    _isEditingProfile = false;
    _isSavingProfile = false;
    notifyListeners();
  }

  void enterEditMode() => _enterEditMode?.call();

  void cancelEditMode() => _cancelEditMode?.call();

  Future<void> saveProfileChanges() async {
    await _saveProfileChanges?.call();
  }
}

class ProfilePage extends StatefulWidget {
  final ProfilePageController? controller;

  const ProfilePage({super.key, this.controller});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  static const List<String> _availableSkills = [
    'Front-end',
    'Backend',
    'Full Stack',
    'UI/UX',
    'Project Management',
    'Data Analysis',
    'Mobile Development',
  ];

  bool _isEditingProfile = false;
  bool _isSavingProfile = false;
  TextEditingController? _nameController;
  TextEditingController? _handleController;
  TextEditingController? _phoneController;
  TextEditingController? _bioController;
  List<String> _selectedSkills = [];
  final ImagePicker _imagePicker = ImagePicker();

  void _log(String message) {
    debugPrint(message);
  }

  bool get isEditingProfile => _isEditingProfile;
  bool get isSavingProfile => _isSavingProfile;

  void _syncController() {
    widget.controller?.bind(
      isEditingProfile: _isEditingProfile,
      isSavingProfile: _isSavingProfile,
      enterEditMode: enterEditMode,
      cancelEditMode: cancelEditMode,
      saveProfileChanges: saveProfileChanges,
    );
  }

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.unbind();
      _syncController();
    }
  }

  void _initializeControllers(UserModel user) {
    _nameController ??= TextEditingController();
    _handleController ??= TextEditingController();
    _phoneController ??= TextEditingController();
    _bioController ??= TextEditingController();
    _syncDraftWithUser(user);
  }

  void _syncDraftWithUser(UserModel user) {
    if (_isEditingProfile) return;

    _nameController?.text = user.userName;
    _handleController?.text = user.userHandle;
    _phoneController?.text = user.userPhoneNumber ?? '';
    _bioController?.text = user.userBio ?? '';
    _selectedSkills = List<String>.from(user.userSkills);
  }

  UserModel _buildDraftUser(UserModel user) {
    return user.copyWith(
      userName: _nameController?.text.trim() ?? user.userName,
      userHandle: _handleController?.text.trim() ?? user.userHandle,
      userPhoneNumber: (_phoneController?.text.trim().isEmpty ?? true)
          ? null
          : _phoneController!.text.trim(),
      userBio: _bioController?.text.trim(),
      userSkills: List<String>.from(_selectedSkills),
    );
  }

  List<String> _missingDiscoverabilityFields(UserModel user) {
    final missingFields = <String>[];

    if (user.userName.isEmpty) missingFields.add('Name');
    if (user.userHandle.isEmpty) missingFields.add('Handle');
    if (user.userBio == null || user.userBio!.isEmpty) {
      missingFields.add('Bio');
    }
    if (user.userSkills.isEmpty) missingFields.add('Skills');

    return missingFields;
  }

  @override
  void dispose() {
    widget.controller?.unbind();
    _nameController?.dispose();
    _handleController?.dispose();
    _phoneController?.dispose();
    _bioController?.dispose();
    super.dispose();
  }

  Future<void> _uploadProfilePicture(
    BuildContext context,
    UserModel user,
  ) async {
    final userProvider = context.read<UserProvider>();
    try {
      // Show image source selection with remove option
      final String? action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Profile Picture'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              if (user.userProfilePicture != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
            ],
          ),
        ),
      );

      if (action == null) return;

      // Handle remove photo
      if (action == 'remove') {
        if (!context.mounted) return;

        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove Profile Picture'),
            content: const Text(
              'Are you sure you want to remove your profile picture?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Remove'),
              ),
            ],
          ),
        );

        if (confirm != true || !context.mounted) return;

        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );

        // Delete from Cloudinary if exists
        if (user.userProfilePicture != null) {
          try {
            await CloudinaryService().deleteProfilePicture(user.userId);
          } catch (e) {
            // Ignore if file doesn't exist
            _log('[DEBUG] Profile picture file not found in cloudinary: $e');
          }
        }

        // Update user profile to null
        final updatedUser = user.copyWith(userProfilePicture: null);
        await userProvider.updateUserData(updatedUser);

        // Close loading
        if (context.mounted) Navigator.pop(context);

        // Show success
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture removed')),
          );
        }
        return;
      }

      // Determine image source
      final ImageSource source = action == 'camera'
          ? ImageSource.camera
          : ImageSource.gallery;

      // Pick image
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null || !context.mounted) return;

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Upload to Cloudinary
      final downloadUrl = await CloudinaryService().uploadProfilePicture(
        File(image.path),
        user.userId,
      );

      // Update user profile
      final updatedUser = user.copyWith(userProfilePicture: downloadUrl);
      await userProvider.updateUserData(updatedUser);

      // Close loading
      if (context.mounted) Navigator.pop(context);

      // Show success
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully')),
        );
      }
    } catch (e) {
      _log('[DEBUG] Error in _uploadProfilePicture: $e');

      // Try to close loading dialog if open
      try {
        if (context.mounted) Navigator.pop(context);
      } catch (_) {}

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return "N/A";
    final date = ts.toDate();
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<bool> _saveProfile(
    BuildContext context,
    UserModel user, {
    bool showSuccessMessage = true,
  }) async {
    final draftUser = _buildDraftUser(user);

    if (draftUser.userName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return false;
    }

    if (draftUser.userHandle.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Handle cannot be empty')));
      return false;
    }

    setState(() {
      _isSavingProfile = true;
    });

    try {
      await context.read<UserProvider>().updateUserData(draftUser);
      if (!mounted) return false;

      setState(() {
        _isEditingProfile = false;
        _isSavingProfile = false;
      });
      _syncController();

      if (showSuccessMessage) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
      return true;
    } catch (e) {
      if (!mounted) return false;

      setState(() {
        _isSavingProfile = false;
      });
      _syncController();

      ScaffoldMessenger.of(
        this.context,
      ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      return false;
    }
  }

  void _startEditing(UserModel user) {
    _initializeControllers(user);
    setState(() {
      _syncDraftWithUser(user);
      _isEditingProfile = true;
    });
    _syncController();
  }

  void _cancelEditing(UserModel user) {
    setState(() {
      _isEditingProfile = false;
      _syncDraftWithUser(user);
    });
    _syncController();
  }

  void enterEditMode() {
    final user = context.read<UserProvider>().currentUser;
    if (user == null || _isEditingProfile) return;
    _startEditing(user);
  }

  void cancelEditMode() {
    final user = context.read<UserProvider>().currentUser;
    if (user == null || !_isEditingProfile) return;
    _cancelEditing(user);
  }

  Future<void> saveProfileChanges() async {
    final user = context.read<UserProvider>().currentUser;
    if (user == null || !_isEditingProfile || _isSavingProfile) return;
    await _saveProfile(context, user);
  }

  Future<void> _toggleDiscoverability(
    BuildContext context,
    bool isDiscoverable,
    UserModel user,
  ) async {
    final userProvider = context.read<UserProvider>();
    final sourceUser = _isEditingProfile ? _buildDraftUser(user) : user;

    // If trying to make the profile discoverable, validate required fields.
    if (isDiscoverable) {
      final missingFields = _missingDiscoverabilityFields(sourceUser);

      if (missingFields.isNotEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please complete the following fields before making your profile discoverable: ${missingFields.join(', ')}',
              ),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(label: 'OK', onPressed: () {}),
            ),
          );
        }
        return;
      }

      if (_isEditingProfile) {
        final saved = await _saveProfile(
          context,
          user,
          showSuccessMessage: false,
        );
        if (!saved || !context.mounted) return;
      }
    }

    try {
      await userProvider.togglePublicProfile(isDiscoverable);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDiscoverable
                  ? 'Your profile is now discoverable'
                  : 'Your profile is now hidden',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile visibility: ${e.toString()}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Widget _buildBioSection(UserModel user) {
    if (_isEditingProfile) {
      return TextField(
        controller: _bioController,
        decoration: const InputDecoration(
          hintText: 'Write something about yourself...',
          border: OutlineInputBorder(),
        ),
        maxLines: 4,
        maxLength: 500,
      );
    }

    return Text(
      user.userBio?.isNotEmpty == true ? user.userBio! : 'No bio added yet',
      style: const TextStyle(fontSize: 14),
    );
  }

  Widget _buildPersonalInfoSection(UserModel user) {
    if (_isEditingProfile) {
      return Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            maxLength: 50,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _handleController,
            decoration: const InputDecoration(
              labelText: 'Handle',
              border: OutlineInputBorder(),
              prefixText: '@',
              prefixIcon: Icon(Icons.alternate_email),
            ),
            maxLength: 30,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
              hintText: '09123456789',
            ),
            keyboardType: TextInputType.phone,
            maxLength: 11,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileInfoRow(
          icon: Icons.person,
          label: 'Name',
          value: user.userName,
        ),
        const SizedBox(height: 8),
        ProfileInfoRow(
          icon: Icons.alternate_email,
          label: 'Handle',
          value: '@${user.userHandle}',
        ),
        const SizedBox(height: 8),
        ProfileInfoRow(
          icon: Icons.phone,
          label: 'Phone',
          value: user.userPhoneNumber ?? 'Not provided',
        ),
      ],
    );
  }

  Widget _buildSkillsSection(UserModel user) {
    if (_isEditingProfile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select up to 3 skills (${_selectedSkills.length}/3)',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableSkills.map((skill) {
              final isSelected = _selectedSkills.contains(skill);
              final canToggle = isSelected || _selectedSkills.length < 3;

              return FilterChip(
                label: Text(skill),
                selected: isSelected,
                onSelected: canToggle
                    ? (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSkills.add(skill);
                          } else {
                            _selectedSkills.remove(skill);
                          }
                        });
                      }
                    : null,
              );
            }).toList(),
          ),
        ],
      );
    }

    if (user.userSkills.isEmpty) {
      return const Text('No skills added yet. Add up to 3 skills.');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: user.userSkills
          .map(
            (skill) => Chip(
              label: Text(skill),
              backgroundColor: const Color(0xFFE7EEFF),
              side: const BorderSide(color: Color(0xFFC7D6FF)),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final user = userProvider.currentUser;

        if (user == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading profile...'),
              ],
            ),
          );
        }

        _initializeControllers(user);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ProfileHeader(
                    user: user,
                    onEditPicture: () => _uploadProfilePicture(context, user),
                  ),
                  ProfileSectionCard(
                    title: 'Bio',
                    child: _buildBioSection(user),
                  ),
                  ProfileSectionCard(
                    title: 'Personal Information',
                    child: _buildPersonalInfoSection(user),
                  ),
                  ProfileSectionCard(
                    title: 'Skills & Interests',
                    child: _buildSkillsSection(user),
                  ),
                  ProfileSectionCard(
                    title: 'Visibility & Status',
                    child: Column(
                      children: [
                        ProfileStatusRow(
                          icon: user.userIsVerified
                              ? Icons.verified
                              : Icons.warning_amber,
                          label: user.userIsVerified
                              ? 'Verified'
                              : 'Unverified',
                          color: user.userIsVerified
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(height: 8),
                        ProfileStatusRow(
                          icon: user.userIsActive
                              ? Icons.check_circle
                              : Icons.cancel,
                          label: user.userIsActive ? 'Active' : 'Inactive',
                          color: user.userIsActive ? Colors.green : Colors.red,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              user.userIsPublic ? Icons.public : Icons.lock,
                              color: const Color(0xFF2563EB),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Discoverable Profile',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Switch(
                              value: user.userIsPublic,
                              onChanged: (value) =>
                                  _toggleDiscoverability(context, value, user),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ProfileSectionCard(
                    title: 'Account Information',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileInfoRow(
                          icon: Icons.calendar_today,
                          label: 'Joined',
                          value: _formatTimestamp(user.userCreatedAt),
                        ),
                        const SizedBox(height: 8),
                        ProfileInfoRow(
                          icon: Icons.login,
                          label: 'Last Login',
                          value: _formatTimestamp(user.userLastLogin),
                        ),
                        const SizedBox(height: 8),
                        ProfileInfoRow(
                          icon: Icons.access_time,
                          label: 'Last Active',
                          value: _formatTimestamp(user.userLastActiveAt),
                        ),
                        const SizedBox(height: 8),
                        ProfileInfoRow(
                          icon: Icons.language,
                          label: 'Locale',
                          value: user.userLocale,
                        ),
                        const SizedBox(height: 8),
                        ProfileInfoRow(
                          icon: Icons.schedule,
                          label: 'Timezone',
                          value: user.userTimezone,
                        ),
                      ],
                    ),
                  ),
                  ProfileSectionCard(
                    title: 'Account Management',
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.lock, color: Colors.orange),
                          title: const Text('Change Password'),
                          subtitle: const Text('Update your account password'),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () => showChangePasswordDialog(context),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(
                            Icons.delete_forever,
                            color: Colors.red,
                          ),
                          title: const Text(
                            'Delete Account',
                            style: TextStyle(color: Colors.red),
                          ),
                          subtitle: const Text(
                            'Permanently delete your account',
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.red,
                          ),
                          onTap: () => showDeleteAccountDialog(context),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

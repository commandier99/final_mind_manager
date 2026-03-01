import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/users/datasources/providers/user_provider.dart';
import '../../features/users/datasources/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../utilities/cloudinary_service.dart';
import 'dart:io';
import '../widgets/profile/profile_header.dart';
import '../widgets/profile/profile_info_row.dart';
import '../widgets/profile/profile_section_card.dart';
import '../widgets/profile/profile_status_row.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditingBio = false;
  TextEditingController? _bioController;
  final ImagePicker _imagePicker = ImagePicker();

  void _log(String message) {
    debugPrint(message);
  }

  @override
  void dispose() {
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

  Future<void> _saveBio(BuildContext context, UserModel user) async {
    if (_bioController == null) return;

    final userProvider = context.read<UserProvider>();
    final updatedUser = user.copyWith(userBio: _bioController!.text.trim());

    try {
      await userProvider.updateUserData(updatedUser);
      setState(() {
        _isEditingBio = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bio updated successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating bio: $e')));
      }
    }
  }

  Future<void> _togglePublicProfile(BuildContext context, bool isPublic) async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.currentUser;

    // If trying to make public, validate required fields
    if (isPublic && user != null) {
      final missingFields = <String>[];

      if (user.userName.isEmpty) missingFields.add('Name');
      if (user.userHandle.isEmpty) missingFields.add('Handle');
      if (user.userBio == null || user.userBio!.isEmpty) {
        missingFields.add('Bio');
      }
      if (user.userSkills.isEmpty) missingFields.add('Skills');

      if (missingFields.isNotEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please complete the following fields before making your profile public: ${missingFields.join(', ')}',
              ),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(label: 'OK', onPressed: () {}),
            ),
          );
        }
        return;
      }
    }

    try {
      await userProvider.togglePublicProfile(isPublic);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPublic ? 'Profile is now public' : 'Profile is now private',
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

  Future<void> _toggleSearchVisibility(
    BuildContext context,
    bool allowSearch,
  ) async {
    try {
      await context.read<UserProvider>().setAllowSearch(allowSearch);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              allowSearch
                  ? 'Your profile can be found in search'
                  : 'Your profile is hidden from search',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating search visibility: $e')),
        );
      }
    }
  }

  void _showEditProfileDialog(BuildContext context, UserModel user) {
    final nameController = TextEditingController(text: user.userName);
    final handleController = TextEditingController(text: user.userHandle);
    final phoneController = TextEditingController(text: user.userPhoneNumber);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Personal Information'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                maxLength: 50,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: handleController,
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
                controller: phoneController,
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
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name cannot be empty')),
                );
                return;
              }

              final updatedUser = user.copyWith(
                userName: nameController.text.trim(),
                userHandle: handleController.text.trim(),
                userPhoneNumber: phoneController.text.trim().isEmpty
                    ? null
                    : phoneController.text.trim(),
              );

              try {
                await context.read<UserProvider>().updateUserData(updatedUser);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating profile: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSkillsDialog(BuildContext context, UserModel user) {
    final availableSkills = [
      'Front-end',
      'Backend',
      'Full Stack',
      'UI/UX',
      'Project Management',
      'Data Analysis',
      'Mobile Development',
    ];
    final selectedSkills = [...user.userSkills];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Manage Skills'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select up to 3 skills (${selectedSkills.length}/3)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ...availableSkills.map((skill) {
                  final isSelected = selectedSkills.contains(skill);
                  final canSelect = selectedSkills.length < 3 || isSelected;

                  return CheckboxListTile(
                    title: Text(skill),
                    value: isSelected,
                    onChanged: canSelect
                        ? (value) {
                            setState(() {
                              if (value == true) {
                                selectedSkills.add(skill);
                              } else {
                                selectedSkills.remove(skill);
                              }
                            });
                          }
                        : null,
                    enabled: canSelect,
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedUser = user.copyWith(userSkills: selectedSkills);

                try {
                  await context.read<UserProvider>().updateUserData(
                    updatedUser,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Skills updated successfully'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating skills: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrent
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                  obscureText: obscureCurrent,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => obscureNew = !obscureNew),
                    ),
                  ),
                  obscureText: obscureNew,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                  obscureText: obscureConfirm,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (currentPasswordController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter your current password'),
                    ),
                  );
                  return;
                }

                if (newPasswordController.text.trim().length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters'),
                    ),
                  );
                  return;
                }

                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match')),
                  );
                  return;
                }

                try {
                  await context.read<UserProvider>().changePassword(
                    currentPassword: currentPasswordController.text.trim(),
                    newPassword: newPasswordController.text.trim(),
                  );

                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password changed successfully'),
                      ),
                    );
                  }
                } catch (e) {
                  String errorMessage = 'Error changing password';

                  final message = e.toString().toLowerCase();
                  if (message.contains('wrong-password') ||
                      message.contains('invalid-credential')) {
                    errorMessage = 'Current password is incorrect';
                  } else if (message.contains('weak-password')) {
                    errorMessage = 'New password is too weak';
                  } else if (message.contains('requires-recent-login')) {
                    errorMessage =
                        'Please log out and log in again before changing password';
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(errorMessage)));
                  }
                }
              },
              child: const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action is permanent and cannot be undone.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 16),
            const Text('All your data will be permanently deleted, including:'),
            const SizedBox(height: 8),
            const Text('- All boards and tasks'),
            const Text('- Profile information'),
            const Text('- Activity history'),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                labelText: 'Type "DELETE" to confirm',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (confirmController.text.trim() != 'DELETE') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please type DELETE to confirm'),
                  ),
                );
                return;
              }

              // Close delete confirmation dialog immediately
              Navigator.pop(dialogContext);

              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingContext) =>
                    const Center(child: CircularProgressIndicator()),
              );

              try {
                // Delete account (errors are handled inside deleteAccount method)
                await context.read<UserProvider>().deleteAccount();

                // Account deletion completed - navigate to login
                // Use Navigator to close loading and go to login in one go
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/auth', (route) => false);
                }
              } catch (e) {
                // Close loading dialog
                if (context.mounted) {
                  Navigator.pop(context);

                  // Show error but still navigate to login since auth might be deleted
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Account deletion completed with warnings. You have been signed out.',
                      ),
                      duration: const Duration(seconds: 5),
                    ),
                  );

                  // Navigate to login anyway
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (context.mounted) {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/auth', (route) => false);
                    }
                  });
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9C88D4),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _log('[DEBUG] ProfilePage: build called');

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

        // Initialize bio controller once with current bio
        _bioController ??= TextEditingController(text: user.userBio ?? '');

        // Update controller text if not editing and bio changed
        if (!_isEditingBio && _bioController!.text != (user.userBio ?? '')) {
          _bioController!.text = user.userBio ?? '';
        }

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
                    action: IconButton(
                      icon: Icon(
                        _isEditingBio ? Icons.check : Icons.edit,
                        size: 20,
                      ),
                      onPressed: () {
                        if (_isEditingBio) {
                          _saveBio(context, user);
                        } else {
                          setState(() {
                            _isEditingBio = true;
                          });
                        }
                      },
                    ),
                    child: _isEditingBio
                        ? TextField(
                            controller: _bioController,
                            decoration: const InputDecoration(
                              hintText: 'Write something about yourself...',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 4,
                            maxLength: 500,
                          )
                        : Text(
                            user.userBio?.isNotEmpty == true
                                ? user.userBio!
                                : 'No bio added yet',
                            style: const TextStyle(fontSize: 14),
                          ),
                  ),
                  ProfileSectionCard(
                    title: 'Personal Information',
                    action: IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditProfileDialog(context, user),
                    ),
                    child: Column(
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
                    ),
                  ),
                  ProfileSectionCard(
                    title: 'Skills & Interests',
                    action: IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showSkillsDialog(context, user),
                    ),
                    child: user.userSkills.isEmpty
                        ? const Text('No skills added yet. Add up to 3 skills.')
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: user.userSkills
                                .map(
                                  (skill) => Chip(
                                    label: Text(skill),
                                    backgroundColor: const Color(0xFFE7EEFF),
                                    side: const BorderSide(
                                      color: Color(0xFFC7D6FF),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
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
                                'Public Profile',
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
                                  _togglePublicProfile(context, value),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.manage_search,
                              color: const Color(0xFF2563EB),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Appear In Search',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Switch(
                              value: user.userAllowSearch,
                              onChanged: (value) =>
                                  _toggleSearchVisibility(context, value),
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
                          onTap: () => _showChangePasswordDialog(context),
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
                          onTap: () => _showDeleteAccountDialog(context),
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

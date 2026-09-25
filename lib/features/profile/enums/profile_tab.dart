/// The two segments of the profile's media section.
enum ProfileTab {
  posts('Posts'),
  archived('Archived Posts');

  const ProfileTab(this.label);

  final String label;
}

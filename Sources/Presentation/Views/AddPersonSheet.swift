import SwiftUI

struct AddPersonSheet: View {
    @Bindable var viewModel: PeopleContentViewModel
    @Binding var selectedCategory: String

    var body: some View {
        VStack(spacing: 0) {
            Text("New person")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                personFieldsSection
                calendarLinkSection
            }
            .padding(16)

            Divider()
            footer
        }
        .frame(width: 360)
    }

    private var personFieldsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Person name")
                TextField("", text: $viewModel.newFolderName)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Category")
                categoryMenu

                Button {
                    viewModel.isAddingFolder = false
                    viewModel.isAddingCategory = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption2.weight(.semibold))
                        Text("New category")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.accentColor)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }

    private var calendarLinkSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption)
                Text("Google Calendar 1-1 event name (optional)")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.secondary)

            TextField("", text: $viewModel.newCalendarEventName)
                .textFieldStyle(.roundedBorder)
                .labelsHidden()

            Text("Used to automatically link the 1-1 Google Calendar event to this person.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 8))
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                viewModel.isAddingFolder = false
                viewModel.newFolderName = ""
                viewModel.newCalendarEventName = ""
            }
            .keyboardShortcut(.cancelAction)
            Spacer()
            Button("Create") {
                viewModel.createPerson(
                    name: viewModel.newFolderName,
                    inCategory: selectedCategory,
                    calendarEventName: viewModel.newCalendarEventName
                )
                viewModel.newFolderName = ""
                viewModel.newCalendarEventName = ""
                viewModel.isAddingFolder = false
            }
            .keyboardShortcut(.defaultAction)
            .disabled(viewModel.newFolderName.trimmingCharacters(in: .whitespaces).isEmpty
                      || selectedCategory.isEmpty)
        }
        .padding(16)
    }

    private var categoryMenu: some View {
        Menu {
            ForEach(viewModel.categoryNames, id: \.self) { name in
                Button(name) { selectedCategory = name }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedCategory.isEmpty ? " " : selectedCategory)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: .rect(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func fieldLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
    }
}

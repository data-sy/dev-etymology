import SwiftUI
import StoreKit

struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0
    @Environment(\.requestReview) private var requestReview

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }

    var body: some View {
        NavigationStack {
            List {
                appearanceSection
                appInfoSection
                supportSection
                legalSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.bg)
            .navigationTitle("설정")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - 외관

    private var appearanceSection: some View {
        Section {
            Picker(selection: $appearanceMode) {
                Text("시스템").tag(0)
                Text("라이트").tag(1)
                Text("다크").tag(2)
            } label: {
                Label {
                    Text("화면 모드")
                        .font(Theme.sans(14, relativeTo: .body))
                        .foregroundStyle(Theme.Palette.text)
                } icon: {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(Theme.Palette.accent)
                        .accessibilityHidden(true)
                }
            }
            .tint(Theme.Palette.accent)
            .accessibilityLabel("화면 모드 선택")
        } header: {
            sectionHeader("외관")
        }
        .listRowBackground(Theme.Palette.surface)
    }

    // MARK: - 앱 정보

    private var appInfoSection: some View {
        Section {
            infoRow(label: "앱 버전", value: appVersion)
            infoRow(label: "빌드 번호", value: buildNumber)
        } header: {
            sectionHeader("앱 정보")
        }
        .listRowBackground(Theme.Palette.surface)
    }

    // MARK: - 지원

    private var supportSection: some View {
        Section {
            mailLink(
                title: "개발자에게 문의",
                icon: "envelope",
                subject: "[문의] DevEtym"
            )
            Button {
                requestReview()
            } label: {
                Label {
                    Text("앱 평가하기")
                        .font(Theme.sans(14, relativeTo: .body))
                        .foregroundStyle(Theme.Palette.text)
                } icon: {
                    Image(systemName: "star")
                        .foregroundStyle(Theme.Palette.accent)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel("앱 스토어에서 앱 평가하기")
            mailLink(
                title: "오류 제보",
                icon: "exclamationmark.bubble",
                subject: "[오류제보] 일반"
            )
        } header: {
            sectionHeader("지원")
        }
        .listRowBackground(Theme.Palette.surface)
    }

    // MARK: - 법적 고지

    private var legalSection: some View {
        Section {
            NavigationLink {
                openSourceLicenseView
            } label: {
                Label {
                    Text("오픈소스 라이선스")
                        .font(Theme.sans(14, relativeTo: .body))
                        .foregroundStyle(Theme.Palette.text)
                } icon: {
                    Image(systemName: "doc.text")
                        .foregroundStyle(Theme.Palette.accent)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel("오픈소스 라이선스 보기")

            aiDisclaimerRow

            if let privacyURL = URL(string: "https://example.com/privacy") {
                Link(destination: privacyURL) {
                    Label {
                        HStack {
                            Text("개인정보 처리방침")
                                .font(Theme.sans(14, relativeTo: .body))
                                .foregroundStyle(Theme.Palette.text)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundStyle(Theme.Palette.textMuted)
                                .accessibilityHidden(true)
                        }
                    } icon: {
                        Image(systemName: "hand.raised")
                            .foregroundStyle(Theme.Palette.accent)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel("개인정보 처리방침 열기")
            }
        } header: {
            sectionHeader("법적 고지")
        }
        .listRowBackground(Theme.Palette.surface)
    }

    // MARK: - 하위 뷰 헬퍼

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.mono(10, weight: .medium, relativeTo: .caption2))
            .foregroundStyle(Theme.Palette.accent)
            .textCase(.uppercase)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.sans(14, relativeTo: .body))
                .foregroundStyle(Theme.Palette.text)
            Spacer()
            Text(value)
                .font(Theme.mono(13, relativeTo: .footnote))
                .foregroundStyle(Theme.Palette.textMuted)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func mailLink(title: String, icon: String, subject: String) -> some View {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let urlString = "mailto:\(Constants.reportEmail)?subject=\(encodedSubject)"
        if let url = URL(string: urlString) {
            Link(destination: url) {
                Label {
                    Text(title)
                        .font(Theme.sans(14, relativeTo: .body))
                        .foregroundStyle(Theme.Palette.text)
                } icon: {
                    Image(systemName: icon)
                        .foregroundStyle(Theme.Palette.accent)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel(title)
        }
    }

    private var aiDisclaimerRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text("AI 생성 고지")
                    .font(Theme.mono(11, weight: .medium, relativeTo: .footnote))
                    .foregroundStyle(Theme.Palette.accentAI)
            } icon: {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.Palette.accentAI)
                    .accessibilityHidden(true)
            }
            Text("이 앱의 모든 어원 설명은 AI(Claude)가 생성합니다. 부정확한 내용이 포함될 수 있습니다.")
                .font(Theme.sans(12, relativeTo: .footnote))
                .foregroundStyle(Theme.Palette.textDim)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var openSourceLicenseView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("DM Sans / DM Mono / DM Serif Display")
                    .font(Theme.mono(13, weight: .medium, relativeTo: .body))
                    .foregroundStyle(Theme.Palette.text)
                Text(oflLicenseText)
                    .font(Theme.sans(12, relativeTo: .footnote))
                    .foregroundStyle(Theme.Palette.textDim)
                    .lineSpacing(3)
            }
            .padding(18)
        }
        .background(Theme.Palette.bg)
        .navigationTitle("오픈소스 라이선스")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var oflLicenseText: String {
        """
        Copyright 2014 The DM Sans Project Authors (https://github.com/googlefonts/dm-fonts)
        Copyright 2020 The DM Mono Project Authors (https://github.com/googlefonts/dm-mono)
        Copyright 2014 The DM Serif Display Project Authors (https://github.com/googlefonts/dm-fonts)

        This Font Software is licensed under the SIL Open Font License, Version 1.1.

        This license is available with a FAQ at: https://openfontlicense.org

        SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007

        PREAMBLE
        The goals of the Open Font License (OFL) are to stimulate worldwide development of collaborative font projects, to support the font creation efforts of academic and linguistic communities, and to provide a free and open framework in which fonts may be shared and improved in partnership with others.

        The fonts are free to use, modify, and redistribute under the terms of this license.

        PERMISSION & CONDITIONS
        Permission is hereby granted, free of charge, to any person obtaining a copy of the Font Software, to use, study, copy, merge, embed, modify, redistribute, and sell modified and unmodified copies of the Font Software, subject to the following conditions:

        1) Neither the Font Software nor any of its individual components, in Original or Modified Versions, may be sold by itself.

        2) Original or Modified Versions of the Font Software may be bundled, redistributed and/or sold with any software, provided that each copy contains the above copyright notice and this license.

        3) No Modified Version of the Font Software may use the Reserved Font Name(s) unless explicit written permission is granted by the corresponding Copyright Holder.

        4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font Software shall not be used to promote, endorse or advertise any Modified Version, except to acknowledge the contribution(s) of the Copyright Holder(s) and the Author(s) or with their explicit written permission.

        5) The Font Software, modified or unmodified, in part or in whole, must be distributed entirely under this license, and must not be distributed under any other license.

        TERMINATION
        This license becomes null and void if any of the above conditions are not met.

        DISCLAIMER
        THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM OTHER DEALINGS IN THE FONT SOFTWARE.
        """
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}

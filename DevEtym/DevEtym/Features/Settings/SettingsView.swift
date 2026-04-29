import SwiftUI
import StoreKit

struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: Int = 2
    @Environment(\.requestReview) private var requestReview
    @Environment(\.analyticsService) private var analyticsService

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }

    /// Toggle 상태를 AnalyticsService.consentGiven과 양방향으로 묶는 Binding
    private var consentBinding: Binding<Bool> {
        Binding(
            get: { analyticsService.consentGiven },
            set: { analyticsService.consentGiven = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                appearanceSection
                appInfoSection
                supportSection
                dataCollectionSection
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
                        .typoBodyLarge()
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
                        .typoBodyLarge()
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

    // MARK: - 데이터 수집 (PIPA 옵트인)

    private var dataCollectionSection: some View {
        Section {
            Toggle(isOn: consentBinding) {
                Label {
                    Text("데이터 수집 동의")
                        .font(Theme.sans(14, relativeTo: .body))
                        .foregroundStyle(Theme.Palette.text)
                } icon: {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .foregroundStyle(Theme.Palette.accent)
                        .accessibilityHidden(true)
                }
            }
            .tint(Theme.Palette.accent)
            .accessibilityLabel("데이터 수집 동의 토글")
            .accessibilityHint("끄면 이후 분석 이벤트가 수집되지 않습니다")

            NavigationLink {
                appInstanceIDView
            } label: {
                Label {
                    Text("내 식별자 보기")
                        .font(Theme.sans(14, relativeTo: .body))
                        .foregroundStyle(Theme.Palette.text)
                } icon: {
                    Image(systemName: "person.text.rectangle")
                        .foregroundStyle(Theme.Palette.accent)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel("내 익명 디바이스 식별자 보기")

            if let privacyURL = URL(string: AppConfig.privacyPolicyURL) {
                Link(destination: privacyURL) {
                    Label {
                        HStack {
                            Text("개인정보 처리방침")
                                .typoBodyLarge()
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
            sectionHeader("데이터 수집")
        } footer: {
            Text("번들 사전 확장 우선순위에 반영하기 위한 익명 이용 데이터만 수집합니다.")
                .font(Theme.sans(11, relativeTo: .caption2))
                .foregroundStyle(Theme.Palette.textMuted)
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
                        .typoBodyLarge()
                        .foregroundStyle(Theme.Palette.text)
                } icon: {
                    Image(systemName: "doc.text")
                        .foregroundStyle(Theme.Palette.accent)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel("오픈소스 라이선스 보기")

            aiDisclaimerRow
        } header: {
            sectionHeader("법적 고지")
        }
        .listRowBackground(Theme.Palette.surface)
    }

    // MARK: - 하위 뷰 헬퍼

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .typoSectionHeader()
            .foregroundStyle(Theme.Palette.accent)
            .textCase(.uppercase)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .typoBodyLarge()
                .foregroundStyle(Theme.Palette.text)
            Spacer()
            Text(value)
                .typoCodeValue()
                .foregroundStyle(Theme.Palette.textMuted)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func mailLink(title: String, icon: String, subject: String) -> some View {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let urlString = "mailto:\(AppConfig.supportEmail)?subject=\(encodedSubject)"
        if let url = URL(string: urlString) {
            Link(destination: url) {
                Label {
                    Text(title)
                        .typoBodyLarge()
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
                    .typoCodeAction()
                    .foregroundStyle(Theme.Palette.accentAI)
            } icon: {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.Palette.accentAI)
                    .accessibilityHidden(true)
            }
            Text("이 앱의 모든 어원 설명은 AI(Claude)가 생성합니다. 부정확한 내용이 포함될 수 있습니다.")
                .typoBodyNotice()
                .foregroundStyle(Theme.Palette.textDim)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// App Instance ID를 표시하고 클립보드 복사를 제공하는 화면
    /// 과거 이벤트 삭제 요청 메일에 이 ID를 첨부하도록 안내한다.
    private var appInstanceIDView: some View {
        AppInstanceIDView(fetchID: { await analyticsService.appInstanceID() })
            .background(Theme.Palette.bg)
            .navigationTitle("내 식별자")
            .navigationBarTitleDisplayMode(.inline)
    }

    private var openSourceLicenseView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("DM Sans / DM Mono / DM Serif Display")
                    .typoCodeBody()
                    .foregroundStyle(Theme.Palette.text)
                Text(oflLicenseText)
                    .typoBodyNotice()
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

// MARK: - 내 식별자 화면

/// Firebase App Instance ID를 비동기로 받아 표시하고 복사 버튼을 제공
private struct AppInstanceIDView: View {
    let fetchID: () async -> String?

    @State private var instanceID: String?
    @State private var isLoading = true
    @State private var didCopy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                descriptionText
                idCard
                Text("과거 이벤트 삭제를 요청하시려면 \(AppConfig.supportEmail)으로 위 식별자를 포함하여 메일을 보내주세요. 앱을 삭제하면 이 ID는 무효화되며 재설치 시 새로 발급됩니다.")
                    .font(Theme.sans(12, relativeTo: .footnote))
                    .foregroundStyle(Theme.Palette.textDim)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
        }
        .task {
            instanceID = await fetchID()
            isLoading = false
        }
    }

    private var descriptionText: some View {
        Text("이 기기에 발급된 익명 디바이스 식별자입니다. 사용자의 이름·이메일 등과 연결되지 않습니다.")
            .font(Theme.sans(13, relativeTo: .body))
            .foregroundStyle(Theme.Palette.text)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var idCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let id = instanceID {
                Text(id)
                    .font(Theme.mono(13, relativeTo: .body))
                    .foregroundStyle(Theme.Palette.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    UIPasteboard.general.string = id
                    didCopy = true
                } label: {
                    Label(didCopy ? "복사됨" : "클립보드에 복사",
                          systemImage: didCopy ? "checkmark" : "doc.on.doc")
                        .font(Theme.sans(12, weight: .medium, relativeTo: .footnote))
                        .foregroundStyle(Theme.Palette.accent)
                }
                .accessibilityLabel("식별자를 클립보드에 복사")
            } else {
                Text("식별자를 가져올 수 없습니다. 데이터 수집 동의 후 앱을 재시작하면 발급됩니다.")
                    .font(Theme.sans(12, relativeTo: .footnote))
                    .foregroundStyle(Theme.Palette.textMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

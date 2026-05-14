"""
8 cell 시스템 프롬프트 조립.

cell 이름 규칙: closing × selfcheck × alias_strict 의 부분집합.
- baseline                              (셋 다 false)
- closing
- selfcheck
- alias_strict
- closing__selfcheck
- closing__alias_strict
- selfcheck__alias_strict
- closing__selfcheck__alias_strict      (셋 다 true)

cell 이름과 코드네임의 의미는 prompts/components.py 상단 docstring 참고.
"""

from prompts.components import (
    PERSONA,
    THINKING_BLOCK_SELFCHECK,
    GOAL_AND_TOOL_SECTION,
    build_field_criteria,
    CLOSING_EXTRA,
    ALIAS_STRICT_EXTRA,
    ACCURACY_AND_CATEGORY,
    FEW_SHOT_EXAMPLES,
)


def build_prompt(use_closing: bool, use_selfcheck: bool, use_alias_strict: bool) -> str:
    """세 변경의 on/off 조합으로 시스템 프롬프트 한 variant를 조립.

    Args:
        use_closing: 약점 1 (namingReason 마무리 문장 제약) 포함 여부
        use_selfcheck: 약점 2 (thinking 단계 자기검수) 포함 여부
        use_alias_strict: 약점 3 (aliases 한정 수식어 부정 예시) 포함 여부
    """
    thinking = THINKING_BLOCK_SELFCHECK if use_selfcheck else ""
    alias_extra = ALIAS_STRICT_EXTRA if use_alias_strict else ""
    closing_extra = CLOSING_EXTRA if use_closing else ""

    field_criteria = build_field_criteria(alias_extra, closing_extra)

    return (
        PERSONA
        + thinking
        + GOAL_AND_TOOL_SECTION
        + field_criteria
        + ACCURACY_AND_CATEGORY
        + FEW_SHOT_EXAMPLES
    )


def cell_name(use_closing: bool, use_selfcheck: bool, use_alias_strict: bool) -> str:
    """코드네임 조합으로 cell 이름 생성. 셋 다 false면 'baseline'.

    이름 순서는 코드네임 알파벳순이 아니라 약점 번호 순서(1·2·3 = closing·selfcheck·alias_strict).
    """
    parts = []
    if use_closing:
        parts.append("closing")
    if use_selfcheck:
        parts.append("selfcheck")
    if use_alias_strict:
        parts.append("alias_strict")
    return "__".join(parts) if parts else "baseline"


# 2³ = 8 cell의 (use_closing, use_selfcheck, use_alias_strict) 조합
CELL_CONFIGS = [
    (False, False, False),  # baseline
    (True,  False, False),  # closing
    (False, True,  False),  # selfcheck
    (False, False, True ),  # alias_strict
    (True,  True,  False),  # closing__selfcheck
    (True,  False, True ),  # closing__alias_strict
    (False, True,  True ),  # selfcheck__alias_strict
    (True,  True,  True ),  # closing__selfcheck__alias_strict
]


# cell 이름 → 시스템 프롬프트 풀텍스트
CELLS: dict[str, str] = {
    cell_name(c, s, a): build_prompt(c, s, a)
    for c, s, a in CELL_CONFIGS
}

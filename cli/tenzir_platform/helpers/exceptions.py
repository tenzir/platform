class PlatformCliError(Exception):
    def __init__(self, error: str):
        super().__init__(error)
        self.error = error
        self.hints: list[str] = []
        self.contexts: list[str] = []

    def add_context(self, context: str) -> "PlatformCliError":
        self.contexts.append(context)
        return self

    # The `Exception` base class already provides the similar `add_note`,
    # but that doesn't return self and there's no public way to access the notes.
    def add_hint(self, hint: str) -> "PlatformCliError":
        self.hints.append(hint)
        return self

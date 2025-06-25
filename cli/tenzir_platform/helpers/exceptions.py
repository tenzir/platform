class PlatformCliError(Exception):
    def __init__(self, error: str):
        super().__init__(error)
        self.error = error
        self.hints: list[str] = []

    def add_hint(self, hint: str):
        self.hints.append(hint)
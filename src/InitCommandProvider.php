<?php
declare(strict_types=1);

namespace Sandstorm\NeosInitE2ETestsPlugin;

use Composer\Plugin\Capability\CommandProvider;

class InitCommandProvider implements CommandProvider
{
    public function getCommands(): array
    {
        return [new InitCommand()];
    }
}

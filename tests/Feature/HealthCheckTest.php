<?php

test('the health check endpoint used by the load balancer responds', function () {
    $this->get('/up')->assertOk();
});
